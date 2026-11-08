import 'package:field_app/screens/long_list_screen.dart';
import 'package:field_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Step 7: open the long list and fling it three times, the same way on
/// every run, while the timeline is recorded (flutter drive --profile).
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('open the long list, fling it three times', (tester) async {
    await binding.traceAction(() async {
      await tester.pumpWidget(MaterialApp(theme: buildTheme(Brightness.light), home: const LongListScreen()));
      await tester.pumpAndSettle();
      final list = find.byType(Scrollable).first;
      for (var i = 0; i < 3; i++) {
        await tester.fling(list, const Offset(0, -2500), 6000);
        await tester.pumpAndSettle();
      }
    }, reportKey: 'scroll');
    // The memory side: how much the decoded photos take in the image cache.
    final cache = PaintingBinding.instance.imageCache;
    debugPrint('image cache: ${cache.currentSize} images, ${cache.currentSizeBytes ~/ 1024} KiB');
  });
}
