import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sync.dart';

/// The banner's sync line: what the cloud has, what waits to be sent.
/// The office assigns the pins (step 1's SQL), so week 4's "Seed my pins" is gone.
class SyncBar extends ConsumerWidget {
  const SyncBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final small = Theme.of(context).textTheme.bodySmall;
    final cloud = ref.watch(myPinsProvider);
    final box = ref.watch(outboxProvider).value;
    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [
      Text(
        switch (cloud) {
          AsyncValue(:final value?) => 'cloud: ${value.length} pins',
          AsyncError() => 'cloud: not reachable',
          _ => 'cloud: connecting…',
        },
        style: small,
      ),
      if (box != null) Text('${box.pending} to send · ${box.failed} refused', style: small),
      TextButton(
        onPressed: () {
          pushSurveys(ref);
          pullPins(ref);
        },
        child: const Text('Sync now'),
      ),
      if (box?.lastError != null)
        Text('last problem: ${box!.lastError}',
            style: small?.copyWith(color: Theme.of(context).colorScheme.error)),
    ]);
  }
}
