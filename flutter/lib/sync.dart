import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'auth.dart';
import 'contract/contract.dart';
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
  if (waiting == 0) return signOut();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text('$waiting survey(s) not sent yet: tap Sync now, then sign out.'),
  ));
}

var _pushing = false;

/// The outbox push: every unsent survey goes up as an update of its entrance's
/// row, by the entrance's UUID, so a second push (the app was killed before it
/// heard "ok") writes the same values again: idempotent. Offline, the call
/// throws at once (Firestore used to wait): the survey stays pending in SQLite
/// and the next trigger sends it.
Future<void> pushSurveys(WidgetRef ref) async {
  if (_pushing) return; // one push at a time
  _pushing = true;
  final db = ref.read(databaseProvider);
  final surveys = ref.read(surveysRepositoryProvider);
  final uid = ref.read(uidProvider);
  try {
    for (final e in await db.outbox()) {
      try {
        await surveys.push(surveyDoc(e, uid));
        await db.markSent(e.id, e.updatedAt, null);
      } on PostgrestException catch (err) {
        // The database said no: the row is not mine any more, or a rule refused it.
        await db.markSent(e.id, e.updatedAt, err.message);
      }
    }
  } catch (_) {
    // No answer (offline, a timeout): nothing is lost, the rows stay pending.
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

  @override
  void initState() {
    super.initState();
    // The push and the pull, at three moments: now (the provider's first
    // fetch), back in the foreground, and when the network comes back. (And on
    // "Sync now"; the push also after a submit.)
    pushSurveys(ref);
    _lifecycle = AppLifecycleListener(onResume: () {
      pushSurveys(ref);
      pullPins(ref);
    });
    _network = Connectivity().onConnectivityChanged.listen((links) {
      if (links.contains(ConnectivityResult.none)) return;
      pushSurveys(ref);
      pullPins(ref);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
