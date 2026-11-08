import 'dart:math';

import 'package:field_app/photo_queue.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dice that always roll the top: the wait is then exactly the ceiling.
class _Top implements Random {
  @override
  double nextDouble() => 1.0;
  @override
  int nextInt(int max) => max - 1;
  @override
  bool nextBool() => true;
}

/// Step 6: week 5's backoff with full jitter (photo_queue.dart).
void main() {
  test('the ceiling doubles from 2 s and stops at 5 minutes', () {
    expect([for (var a = 0; a < 10; a++) retryDelay(a, _Top())],
        [2000, 4000, 8000, 16000, 32000, 64000, 128000, 256000, 300000, 300000]);
  });

  test('every wait is between 0 and the ceiling (jitter), whatever the dice', () {
    final dice = Random(2026); // seeded: the same numbers on every run
    for (var attempt = 0; attempt < 12; attempt++) {
      final ceiling = min(capMs, baseMs * pow(2, attempt).toInt());
      for (var i = 0; i < 500; i++) {
        expect(retryDelay(attempt, dice), inInclusiveRange(0, ceiling));
      }
    }
  });
}
