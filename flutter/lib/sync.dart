import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth.dart';
import 'contract/contract.dart';
import 'providers.dart';

/// Server state: my pins as the cloud has them, live (one Firestore listener).
/// The banner watches it; SyncScope copies every new list into SQLite.
final myPinsProvider = StreamProvider<List<Entrance>>(
  (ref) => ref.watch(pinsRepositoryProvider).watchMine(ref.watch(uidProvider)),
);

/// Wraps the signed-in app: while it is on screen, the pull runs. Signing out
/// removes it, and Riverpod stops the listener nobody watches any more.
class SyncScope extends ConsumerStatefulWidget {
  const SyncScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SyncScope> createState() => _SyncScopeState();
}

class _SyncScopeState extends ConsumerState<SyncScope> {
  @override
  void initState() {
    super.initState();
    // The pull: every snapshot of my pins goes to SQLite, the truth on the
    // phone. listenManual keeps the listener alive while this widget lives.
    ref.listenManual(myPinsProvider, (_, next) {
      final pins = next.value;
      if (pins != null) ref.read(databaseProvider).savePins(pins);
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
