import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

/// Step 7: turns the recorded timeline into a summary (frame build and
/// raster times, frames over budget) in build/scroll.timeline_summary.json.
Future<void> main() => integrationDriver(
      responseDataCallback: (data) async {
        if (data == null) return;
        final timeline = driver.Timeline.fromJson(data['scroll'] as Map<String, dynamic>);
        await driver.TimelineSummary.summarize(timeline).writeTimelineToFile('scroll', pretty: true, includeSummary: true);
      },
    );
