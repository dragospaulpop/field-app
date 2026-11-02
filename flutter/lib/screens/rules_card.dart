import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../contract/contract.dart';
import '../providers.dart';
import '../supabase_repositories.dart';
import '../sync.dart';

/// Dev only (kDebugMode): try the server's rules from the app. A release build
/// has no such card.
class RulesCard extends ConsumerStatefulWidget {
  const RulesCard({super.key, required this.entrance});

  final Entrance entrance;

  @override
  ConsumerState<RulesCard> createState() => _RulesCardState();
}

class _RulesCardState extends ConsumerState<RulesCard> {
  String? _answer;

  /// lat is the office's column: no column grant, so the database refuses.
  Future<void> _moveOfficePin() async {
    try {
      await supabase
          .from('entrances')
          .update({'lat': widget.entrance.lat + 0.001})
          .eq('id', widget.entrance.id)
          .select('id');
      setState(() => _answer = 'The server let it through!');
    } on PostgrestException catch (e) {
      setState(() => _answer = 'Refused: ${e.code} ${e.message}');
    }
  }

  /// A survey the form would never send: the check constraint refuses it.
  Future<void> _sendInvalid() async {
    await ref.read(databaseProvider).forceInvalidSurvey(widget.entrance.id);
    setState(() => _answer = 'Sent stories = 99: see the sync chip.');
    pushSurveys(ref);
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Dev: try the server\'s rules', style: Theme.of(context).textTheme.titleSmall),
          Wrap(spacing: 8, children: [
            OutlinedButton(onPressed: _moveOfficePin, child: const Text('Move the office pin')),
            OutlinedButton(onPressed: _sendInvalid, child: const Text('Send stories = 99')),
          ]),
          if (_answer != null) Text(_answer!, style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
    );
  }
}
