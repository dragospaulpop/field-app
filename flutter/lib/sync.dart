import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException, PostgresChangeEvent, RealtimeChannel, RealtimeSubscribeStatus;

import 'auth.dart';
import 'photo_queue.dart';
import 'contract/contract.dart';
import 'db/database.dart' show QueueState;
import 'providers.dart';
import 'push.dart';
import 'repositories.dart';
import 'supabase_repositories.dart';

/// Server state: my pins as the cloud has them, from the last fetch. The
/// banner watches it; SyncScope copies every new list into SQLite.
/// pullPins asks again: Riverpod throws the old stream away and starts a new one.
final myPinsProvider = StreamProvider<List<Entrance>>(
  (ref) => ref.watch(pinsRepositoryProvider).watchMine(ref.watch(uidProvider)),
);

final outboxProvider = StreamProvider(
  (ref) => ref.watch(databaseProvider).watchOutbox(),
);

/// The pull, again: on start, back in the foreground, on "Sync now" and,
/// since step 3, whenever the office changes one of my entrances.
void pullPins(WidgetRef ref) => ref.invalidate(myPinsProvider);

/// Step 3: Postgres Changes on entrances. RLS still decides: the phone hears
/// only about rows its select policy shows it (its own entrances). Any event
/// is a knock on the door: run the pull, never write the event's row (the
/// pull is the one path into SQLite, with its rules for pending surveys).
RealtimeChannel listenToEntrances(void Function() pull) => supabase
    .channel('entrances')
    .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'entrances',
      callback: (_) => pull(),
    )
    .subscribe((status, error) {
      // (Re)joined: anything missed while away arrives with one pull.
      if (status == RealtimeSubscribeStatus.subscribed) pull();
      if (error != null) debugPrint('entrances channel $status: $error');
    });

/// Sign out only when nothing waits to be sent. The local database is not
/// per user: the next worker's push would send this one's surveys, the server
/// would refuse them (not theirs) and the pull would delete them. So the
/// worker sends first (or deletes the surveys on purpose, a later feature).
Future<void> signOutIfSent(BuildContext context, WidgetRef ref) async {
  final box = await ref.read(databaseProvider).watchOutbox().first;
  final waiting = box.pending + box.failed;
  // Step 4: the photo queue too (every row not synced yet).
  final queue = (await ref.read(databaseProvider).watchQueue().first).counts;
  final photos = queue.entries.where((q) => q.key != QueueState.synced).fold(0, (n, q) => n + q.value);
  var why = '$waiting survey(s) and $photos photo(s) not sent yet: tap Sync now (or Retry photos), then sign out.';
  if (waiting == 0 && photos == 0) {
    try {
      return await signOut();
    } catch (e) {
      // Step 5: this phone's push row could not be deleted: stay signed in.
      debugPrint('sign-out stopped: $e');
      // The map banner's test: "with a connection" only when there is none.
      final offline = (await Connectivity().checkConnectivity()).contains(ConnectivityResult.none);
      why = 'Not signed out: this phone would keep receiving your pushes. Try again${offline ? ' with a connection' : ''}.';
    }
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(why)));
}

var _pushing = false;

/// Errors a retry cannot fix: permission (42501), a check (23514), a missing
/// value (23502), a value of the wrong type (22P02). Everything else is retried.
const _permanent = {'42501', '23514', '23502', '22P02'};

/// What the worker reads: a sentence, not a code.
String sentenceFor(PostgrestException e) => switch (e.code) {
      '42501' => 'This app tried to change something only the office may change. Tell your teacher: it is a bug.',
      '23514' => 'One of the numbers is outside what the form allows.',
      _ => 'The server refused a value of this survey (${e.code}).',
    };

/// The outbox push: every pending survey goes to upsert_survey, by the
/// entrance's UUID, with the updatedAt it was saved with. Four outcomes:
/// applied (synced), lost (a newer version won: the phone takes the server's),
/// refused (failed, with a sentence) and no answer (still pending).
Future<void> pushSurveys(WidgetRef ref) async {
  if (_pushing) return; // one push at a time
  _pushing = true;
  final db = ref.read(databaseProvider);
  final surveys = ref.read(surveysRepositoryProvider);
  final pins = ref.read(pinsRepositoryProvider);
  final uid = ref.read(uidProvider);
  try {
    for (final e in await db.outbox()) {
      try {
        if (await surveys.push(surveyDoc(e, uid))) {
          await db.markSent(e.id, e.updatedAt, null); // applied
        } else {
          // Lost: nothing changed on the server. Pull that one row: if it is
          // there, its newer values replace the worker's; if not, the pin is no
          // longer mine, and the next pull removes it from the phone.
          final server = await pins.pullOne(e.id);
          if (server?.updatedAt == e.updatedAt) {
            await db.markSent(e.id, e.updatedAt, null); // the same survey, resent: it was there already
          } else if (server != null) {
            await db.takeServerVersion(server, 'A newer change of this entrance was kept: these are its values.');
          } else {
            await db.markSent(e.id, e.updatedAt, null);
            pullPins(ref);
          }
        }
      } on PostgrestException catch (err) {
        if (_permanent.contains(err.code)) {
          await db.markSent(e.id, e.updatedAt, sentenceFor(err)); // refused: failed
        } else {
          await db.markWaiting(e.id, e.updatedAt, 'Could not reach the server: it will try again.');
        }
      }
    }
  } catch (_) {
    // No answer at all (offline, a timeout): nothing is lost, the rows stay pending.
  } finally {
    _pushing = false;
  }
}

/// Wraps the signed-in app: while it is on screen, the pull runs. Signing out
/// removes it, and Riverpod stops the listener nobody watches any more.
class SyncScope extends ConsumerStatefulWidget {
  const SyncScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SyncScope> createState() => _SyncScopeState();
}

class _SyncScopeState extends ConsumerState<SyncScope> {
  late final AppLifecycleListener _lifecycle;
  late final StreamSubscription<List<ConnectivityResult>> _network;
  late final PhotoQueue _queue = ref.read(photoQueueProvider);
  RealtimeChannel? _entrances;

  /// Step 3: (re)join the entrances channel; one at a time.
  void _listen() {
    if (_entrances case final old?) supabase.removeChannel(old);
    _entrances = listenToEntrances(() => pullPins(ref));
  }

  @override
  void initState() {
    super.initState();
    // The push and the pull, at three moments: now (the provider's first
    // fetch), back in the foreground, and when the network comes back. (And on
    // "Sync now"; the push also after a submit.)
    pushSurveys(ref);
    // Step 5: signed in, so this phone may receive the office's pushes.
    registerThisPhone();
    // The photo queue resumes: rows cut off mid-upload go back to pending,
    // photos from before the queue join it, then the worker starts.
    final db = ref.read(databaseProvider);
    db.resumeUploading().then((_) => enqueueLeftovers(db, ref.read(uidProvider))).then((_) => _queue.drain());
    _listen();
    _lifecycle = AppLifecycleListener(
      // In the background the socket is the OS's to kill: leave, and join
      // again (with a pull) when the worker comes back.
      onPause: () {
        if (_entrances case final c?) supabase.removeChannel(c);
        _entrances = null;
      },
      onResume: () {
        pushSurveys(ref);
        pullPins(ref);
        _queue.drain();
        _listen();
      },
    );
    _network = Connectivity().onConnectivityChanged.listen((links) {
      if (links.contains(ConnectivityResult.none)) return;
      pushSurveys(ref);
      pullPins(ref);
      _queue.drain();
    });
    // The pull: every list of my pins goes to SQLite, the truth on the
    // phone. listenManual keeps the provider alive while this widget lives.
    ref.listenManual(myPinsProvider, (_, next) {
      final pins = next.value;
      // An empty answer is also what row level security returns when it hides
      // every row: never read it as "all my pins are gone". (A real "none left"
      // waits for the next pull that brings a pin.)
      if (pins != null && pins.isNotEmpty) ref.read(databaseProvider).savePins(pins);
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _network.cancel();
    _queue.stop(); // signed out: no wake-up until someone signs in again
    if (_entrances case final c?) supabase.removeChannel(c); // never another worker's channel
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
