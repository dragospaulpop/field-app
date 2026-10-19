import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../contract/contract.dart';
import '../store.dart';
import 'status_chip.dart';

const _surveyed = {SurveyStatus.submitted, SurveyStatus.approved, SurveyStatus.needs_rework};

class BuildingScreen extends StatelessWidget {
  const BuildingScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final building = store.fixtures.buildings.where((b) => b.id == id).firstOrNull;
    final entrances = store.entrances.where((e) => e.buildingId == id).toList();
    final surveyed = entrances.where((e) => _surveyed.contains(e.surveyStatus)).length;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(building?.label ?? 'Building')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(building?.label ?? 'Building', style: text.headlineSmall),
          if (building?.comment != null) Text(building!.comment!),
          Text('${entrances.length} entrances · $surveyed submitted'),
          const SizedBox(height: 8),
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
