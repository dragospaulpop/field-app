import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../contract/contract.dart';
import '../route_filter.dart';
import '../store.dart';
import 'status_chip.dart';

class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key});

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  // The shell keeps this branch alive, so the choice survives a trip to a
  // detail and back.
  StopStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final f = store.fixtures;
    final route = f.routes.firstWhere((r) => r.workerId == f.me);
    final stops = filterStops(f.stops.where((s) => s.routeId == route.id), _filter);
    return Scaffold(
      appBar: AppBar(title: Text('${route.name} · ${route.date}')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Wrap(
              spacing: 8,
              children: [
                for (final MapEntry(key: status, value: label) in stopFilters.entries)
                  ChoiceChip(
                    label: Text(label),
                    selected: _filter == status,
                    onSelected: (_) => setState(() => _filter = status),
                  ),
              ],
            ),
          ),
          Expanded(
            child: stops.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(emptyText(_filter)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: stops.length,
                    itemBuilder: (context, i) {
                      final e = store.entrance(stops[i].entranceId)!;
                      return Card(
                        child: ListTile(
                          leading: Text('${stops[i].order}',
                              style: Theme.of(context).textTheme.titleLarge),
                          title: Text('${e.street} ${e.number}'),
                          subtitle: Text(e.entranceName),
                          trailing: StatusChip(status: e.surveyStatus),
                          onTap: () => context.push('/entrances/${e.id}'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
