import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart' show QueueState;
import '../photo_queue.dart';
import '../providers.dart';
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
          ref.read(photoQueueProvider).drain();
        },
        child: const Text('Sync now'),
      ),
      if (box?.lastError != null)
        Text('last problem: ${box!.lastError}',
            style: small?.copyWith(color: Theme.of(context).colorScheme.error)),
      if (ref.watch(queueProvider).value case (:final counts, :final lastError)) ...[
        Text(
          'photos: ${counts[QueueState.pending]} waiting · ${counts[QueueState.uploading]} sending · '
          '${counts[QueueState.synced]} sent · ${counts[QueueState.failed]} failed',
          style: small,
        ),
        if (lastError != null) Text('last photo problem: $lastError', style: small),
      ],
      if ((ref.watch(queueProvider).value?.counts[QueueState.failed] ?? 0) > 0)
        TextButton(
          onPressed: () async {
            await ref.read(databaseProvider).retryPhotos();
            ref.read(photoQueueProvider).drain();
          },
          child: const Text('Retry photos'),
        ),
      Row(mainAxisSize: MainAxisSize.min, children: [
        Switch(
          value: ref.watch(allowCellularProvider),
          onChanged: (on) {
            ref.read(allowCellularProvider.notifier).set(on);
            ref.read(photoQueueProvider).drain();
          },
        ),
        Text('Photos on mobile data', style: small),
      ]),
    ]);
  }
}
