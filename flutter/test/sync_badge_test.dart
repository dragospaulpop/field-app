import 'package:field_app/contract/contract.dart' show SyncState;
import 'package:field_app/screens/sync_chip.dart';
import 'package:field_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Step 6: one widget test. Step 2's rule: a state is a word and an icon,
/// colour is the third cue, and the colours come from the theme.
void main() {
  for (final b in Brightness.values) {
    testWidgets('a refused survey says so in words and an icon (${b.name})', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(b),
        home: const Scaffold(body: SyncBadge(state: SyncState.failed)),
      ));
      expect(find.text('Refused'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      final box = tester.widget<Container>(find.descendant(of: find.byType(Pill), matching: find.byType(Container)));
      final tokens = b == Brightness.light ? SyncColors.light : SyncColors.dark;
      expect((box.decoration! as BoxDecoration).color, tokens.failed);
    });
  }
}
