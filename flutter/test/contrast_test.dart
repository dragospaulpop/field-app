import 'package:field_app/contract/contract.dart';
import 'package:field_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2.2's contrast ratio: (L1 + 0.05) / (L2 + 0.05), the lighter first.
/// computeLuminance() is WCAG's relative luminance of an sRGB colour.
double contrast(Color a, Color b) {
  final (x, y) = (a.computeLuminance(), b.computeLuminance());
  return (x > y ? x + 0.05 : y + 0.05) / (x > y ? y + 0.05 : x + 0.05);
}

String hex(Color c) => '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

void main() {
  for (final brightness in Brightness.values) {
    test('every text/background pair of the ${brightness.name} theme is at least 4.5:1', () {
      final theme = buildTheme(brightness);
      final s = theme.colorScheme;
      final sync = theme.extension<SyncColors>()!;
      final pairs = <String, (Color, Color)>{
        'text on surface': (s.onSurface, s.surface),
        'muted text on card': (s.onSurfaceVariant, s.surfaceContainerLow),
        'button text on primary': (s.onPrimary, s.primary),
        'error text on surface': (s.error, s.surface),
        for (final st in SurveyStatus.values)
          'status ${st.name}': (statusLook(s, st).fg, statusLook(s, st).bg),
        for (final st in SyncState.values) 'sync ${st.name}': (sync.of(st).$2, sync.of(st).$1),
      };
      for (final MapEntry(key: name, value: (fg, bg)) in pairs.entries) {
        final r = contrast(fg, bg);
        // ignore: avoid_print
        print('${brightness.name.padRight(5)} ${name.padRight(24)} ${hex(fg)} on ${hex(bg)}  ${r.toStringAsFixed(2)}');
        expect(r, greaterThanOrEqualTo(4.5), reason: '$name in ${brightness.name}');
      }
    });
  }
}
