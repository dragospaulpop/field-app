import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'auth.dart';
import 'photo_queue.dart';
import 'contract/contract.dart';
import 'db/database.dart' show QueueState;
import 'providers.dart';
import 'repositories.dart';

/// Server state: my pins as the cloud has them, from the last fetch. The
/// banner watches it; SyncScope copies every new list into SQLite.
/// pullPins asks again: Riverpod throws the old stream away and starts a new one.
final myPinsProvider = StreamProvider<List<Entrance>>(
  (ref) => ref.watch(pinsRepositoryProvider).watchMine(ref.watch(uidProvider)),
);

final outboxProvider = StreamProvider(
  (ref) => ref.watch(databaseProvider).watchOutbox(),
);

/// The pull, again: on start, back in the foreground and on "Sync now".
void pullPins(WidgetRef ref) => ref.invalidate(myPinsProvider);

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
  if (waiting == 0 && photos == 0) return signOut();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text('$waiting survey(s) and $photos photo(s) not sent yet: tap Sync now (or Retry photos), then sign out.'),
  ));
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

  @override
  void initState() {
    super.initState();
    // The push and the pull, at three moments: now (the provider's first
    // fetch), back in the foreground, and when the network comes back. (And on
    // "Sync now"; the push also after a submit.)
    pushSurveys(ref);
    // The photo queue resumes: rows cut off mid-upload go back to pending,
    // photos from before the queue join it, then the worker starts.
    final db = ref.read(databaseProvider);
    db.resumeUploading().then((_) => enqueueLeftovers(db, ref.read(uidProvider))).then((_) => _queue.drain());
    _lifecycle = AppLifecycleListener(onResume: () {
      pushSurveys(ref);
      pullPins(ref);
      _queue.drain();
    });
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
      if (pins != null) ref.read(databaseProvider).savePins(pins);
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _network.cancel();
    _queue.stop(); // signed out: no wake-up until someone signs in again
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
