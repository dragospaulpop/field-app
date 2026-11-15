import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../contract/contract.dart';
import '../providers.dart';
import '../sync.dart';

final _syncProvider = StreamProvider.family<({SyncState state, String? lastError})?, String>(
  (ref, id) => ref.watch(databaseProvider).watchSync(id),
);

/// One entrance's sync state, honestly: pending (waiting to be sent), synced
/// (the server has this version, or kept a newer one) or failed (with why,
/// and a way out).
class SyncChip extends ConsumerWidget {
  const SyncChip({super.key, required this.entranceId});

  final String entranceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(_syncProvider(entranceId)).value;
    if (s == null) return const SizedBox.shrink();
    final (label, color) = switch (s.state) {
      SyncState.pending => ('Waiting to send', const Color(0xFFB45309)),
      SyncState.synced => ('Synced', const Color(0xFF15803D)),
      SyncState.failed => ('Refused', const Color(0xFFDC2626)),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Chip(
        visualDensity: VisualDensity.compact,
        backgroundColor: color,
        label: Text(label, style: const TextStyle(color: Colors.white)),
      ),
      if (s.lastError case final why?) Text(why, style: Theme.of(context).textTheme.bodySmall),
      if (s.state == SyncState.failed)
        TextButton(
          onPressed: () async {
            await ref.read(databaseProvider).retrySurvey(entranceId);
            pushSurveys(ref);
          },
          child: const Text('Retry'),
        ),
    ]);
  }
}
