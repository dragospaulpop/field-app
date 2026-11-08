import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../contract/contract.dart';
import '../providers.dart';
import '../sync.dart';
import '../theme/app_theme.dart';

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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SyncBadge(state: s.state),
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

/// The one place that knows what a sync state looks like (step 2): the word,
/// the icon and the pair from the theme's SyncColors.
class SyncBadge extends StatelessWidget {
  const SyncBadge({super.key, required this.state});

  final SyncState state;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = Theme.of(context).extension<SyncColors>()!.of(state);
    final (label, icon) = switch (state) {
      SyncState.pending => ('Waiting to send', Icons.schedule_send_outlined),
      SyncState.synced => ('Synced', Icons.cloud_done_outlined),
      SyncState.failed => ('Refused', Icons.error_outline),
    };
    return Pill(label: label, icon: icon, bg: bg, fg: fg);
  }
}
