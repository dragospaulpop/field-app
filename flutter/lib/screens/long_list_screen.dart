import 'dart:math';

import 'package:flutter/material.dart';

import '../contract/contract.dart' show SurveyStatus;
import 'status_chip.dart';

/// Step 7: a made-up list to measure, never the real sync data. 3,000
/// surveys with a photo each, the same on every run (seeded dice), so a
/// before and an after measure exactly the same list.
typedef LongRow = ({int n, String street, String entrance, SurveyStatus status, String photo});

const rowCount = 3000;
const _streets = ['Calea Victoriei', 'Strada Franceză', 'Bulevardul Decebal', 'Strada Lipscani', 'Calea Moșilor'];

List<LongRow> generateRows([int count = rowCount]) {
  final dice = Random(42);
  return [
    for (var n = 0; n < count; n++)
      (
        n: n,
        street: '${_streets[dice.nextInt(_streets.length)]} ${1 + dice.nextInt(200)}',
        entrance: 'Sc. ${String.fromCharCode(65 + dice.nextInt(6))}',
        status: SurveyStatus.values[dice.nextInt(SurveyStatus.values.length)],
        // Six real photos (1200 × 900 JPEG, like a phone's, only smaller).
        photo: 'assets/perf/door-${1 + n % 6}.jpg',
      ),
  ];
}

class LongListScreen extends StatelessWidget {
  const LongListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rows = generateRows();
    return Scaffold(
      appBar: AppBar(title: const Text('Dev: 3,000 surveys')),
      // AFTER: a row is built only when it scrolls into view, every row is
      // 72 dp high (no layout to find where row 2,000 starts), and the photo
      // is decoded at the size it is shown.
      body: ListView.builder(
        itemCount: rows.length,
        itemExtent: 72,
        itemBuilder: (context, i) => _Row(rows[i]),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.r);

  final LongRow r;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            r.photo,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            // Decode 56 dp in physical pixels, not 1200 × 900 (the height follows).
            cacheWidth: (56 * MediaQuery.devicePixelRatioOf(context)).round(),
          ),
        ),
        title: Text('#${r.n + 1} · ${r.street}'),
        subtitle: Text(r.entrance),
        trailing: StatusChip(status: r.status),
      );
}
