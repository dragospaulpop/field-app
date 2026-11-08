import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth.dart';
import '../contract/contract.dart';
import '../providers.dart';
import '../supabase_repositories.dart';
import 'status_chip.dart';

const _surveyed = {SurveyStatus.submitted, SurveyStatus.approved, SurveyStatus.needs_rework};

/// One person on the building's channel, as their phone said it (a claim, not a fact).
typedef Here = ({String userId, String email, String since});

class BuildingScreen extends ConsumerStatefulWidget {
  const BuildingScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<BuildingScreen> createState() => _BuildingScreenState();
}

class _BuildingScreenState extends ConsumerState<BuildingScreen> {
  RealtimeChannel? _channel;
  List<Here> _here = const [];
  String? _problem;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _join();
    // A phone is not a laptop: leave when the app goes to the background
    // (others see a leave, not a ghost), join again when it comes back.
    _lifecycle = AppLifecycleListener(onPause: _leave, onResume: _join);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _leave();
    super.dispose();
  }

  /// Step 3: the private channel `building:<id>`. Realtime asks the policies on
  /// realtime.messages when we join: a worker with no entrance here is refused.
  void _join() {
    _leave();
    final uid = ref.read(uidProvider);
    final email = ref.read(authStateProvider).value?.email ?? '';
    final channel = supabase.channel(
      'building:${widget.id}',
      opts: const RealtimeChannelConfig(private: true), // the default key: one per client
    );
    _channel = channel;
    channel.onPresenceSync((_) {
      // Rebuild the whole list from the state on every sync, never add and
      // subtract on join/leave. One line per person: the same worker on two
      // devices is two keys but one userId.
      final people = <String, Here>{};
      for (final client in channel.presenceState()) {
        for (final p in client.presences) {
          final id = p.payload['userId'] as String?;
          if (id == null) continue;
          people[id] = (userId: id, email: '${p.payload['email']}', since: '${p.payload['since']}');
        }
      }
      if (mounted) setState(() => _here = people.values.toList()..sort((a, b) => a.email.compareTo(b.email)));
    }).subscribe((status, error) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        // track only after SUBSCRIBED; a small payload, sent once per join.
        await channel.track({'userId': uid, 'email': email, 'since': DateTime.now().toUtc().toIso8601String()});
        if (mounted) setState(() => _problem = null);
      } else if (status == RealtimeSubscribeStatus.channelError || status == RealtimeSubscribeStatus.timedOut) {
        debugPrint('building:${widget.id} $status: $error'); // the whole error: its cause says why
        // The server's refusal of the join says Unauthorized; anything else
        // (a timeout, a dropped socket) is the network, not the policy.
        final refused = '$error'.contains('Unauthorized');
        if (mounted) {
          setState(() {
            _here = const [];
            _problem = refused
                ? 'Not on this building\'s channel: none of its entrances is yours.'
                : 'No connection to this building\'s channel: it joins again when the app comes back.';
          });
        }
      }
    });
  }

  /// Untrack and remove: others see a leave at once.
  void _leave() {
    final channel = _channel;
    if (channel == null) return;
    _channel = null;
    unawaited(channel.untrack());
    unawaited(supabase.removeChannel(channel));
  }

  @override
  Widget build(BuildContext context) {
    final building = ref.watch(buildingProvider(widget.id)).value;
    final entrances = [
      for (final e in ref.watch(entrancesProvider).value ?? const <Entrance>[])
        if (e.buildingId == widget.id) e,
    ];
    final surveyed = entrances.where((e) => _surveyed.contains(e.surveyStatus)).length;
    final text = Theme.of(context).textTheme;
    final me = ref.watch(uidProvider);
    return Scaffold(
      appBar: AppBar(title: Text(building?.label ?? 'Building')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(building?.label ?? 'Building', style: text.headlineSmall),
          if (building?.comment != null) Text(building!.comment!),
          Text('${entrances.length} entrances · $surveyed submitted'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Here now (${_here.length})', style: text.titleMedium),
                if (_problem != null) Text(_problem!, style: text.bodySmall),
                for (final h in _here)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person_pin_circle_outlined),
                    title: Text(h.userId == me ? '${h.email} (you)' : h.email),
                    // Another phone's payload: a bad 'since' must not break the screen.
                    subtitle: switch (DateTime.tryParse(h.since)) {
                      final t? => Text('since ${t.toLocal().toString().substring(11, 16)}'),
                      null => null,
                    },
                  ),
              ]),
            ),
          ),
          for (final e in entrances)
            Card(
              child: ListTile(
                title: Text(e.entranceName),
                subtitle: Text('${e.street} ${e.number}'),
                trailing: StatusChip(status: e.surveyStatus),
                onTap: () => context.push('/entrances/${e.id}'),
              ),
            ),
        ],
      ),
    );
  }
}
