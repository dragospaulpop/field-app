import 'package:flutter/material.dart';

import '../contract/contract.dart' show SurveyStatus, SyncState;

/// Week 6, step 2: the app's one theme. Every screen reads its colours from
/// Theme.of(context); the only hex values in the app are in this file: the
/// seed and the sync states' pairs (checked by test/contrast_test.dart).
const seed = Color(0xFFC2410C); // the app's orange since week 2

/// Light or dark, from one seed: ColorScheme.fromSeed computes every role
/// (primary, surface, error… and their "on" colours) for that brightness.
ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
  // 48 dp high and as wide as its parent: every main action is easy to hit.
  const big = Size.fromHeight(48);
  final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  return ThemeData(
    colorScheme: scheme,
    // Our own tokens travel with the theme, one set per brightness.
    extensions: [brightness == Brightness.light ? SyncColors.light : SyncColors.dark],
    // Component themes: set once here, so no screen styles a Card or a button.
    appBarTheme: AppBarThemeData(backgroundColor: scheme.surfaceContainer),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: rounded.copyWith(side: BorderSide(color: scheme.outlineVariant)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: big, shape: rounded),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: big, shape: rounded),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
    ),
    chipTheme: ChipThemeData(shape: const StadiumBorder(), side: BorderSide.none),
  );
}

/// The sync states (week 5) as tokens: a background and the text on it, for
/// light and for dark. Named by meaning, never by colour. A ThemeExtension is
/// how a ThemeData carries tokens Material does not have.
@immutable
class SyncColors extends ThemeExtension<SyncColors> {
  const SyncColors({
    required this.pending,
    required this.onPending,
    required this.synced,
    required this.onSynced,
    required this.failed,
    required this.onFailed,
  });

  final Color pending, onPending, synced, onSynced, failed, onFailed;

  static const light = SyncColors(
    pending: Color(0xFFFFF1D6),
    onPending: Color(0xFF7A4B00),
    synced: Color(0xFFDCFCE7),
    onSynced: Color(0xFF14532D),
    failed: Color(0xFFFEE2E2),
    onFailed: Color(0xFF9B1C1C),
  );

  // Its own calculation, not light inverted: dark tints, light text.
  static const dark = SyncColors(
    pending: Color(0xFF3A2A08),
    onPending: Color(0xFFFFD28A),
    synced: Color(0xFF052E16),
    onSynced: Color(0xFF86EFAC),
    failed: Color(0xFF450A0A),
    onFailed: Color(0xFFFCA5A5),
  );

  /// The pair of one state: (background, text).
  (Color, Color) of(SyncState s) => switch (s) {
        SyncState.pending => (pending, onPending),
        SyncState.synced => (synced, onSynced),
        SyncState.failed => (failed, onFailed),
      };

  @override
  SyncColors copyWith({
    Color? pending,
    Color? onPending,
    Color? synced,
    Color? onSynced,
    Color? failed,
    Color? onFailed,
  }) =>
      SyncColors(
        pending: pending ?? this.pending,
        onPending: onPending ?? this.onPending,
        synced: synced ?? this.synced,
        onSynced: onSynced ?? this.onSynced,
        failed: failed ?? this.failed,
        onFailed: onFailed ?? this.onFailed,
      );

  /// Between two themes (light to dark), the colours fade instead of jumping.
  @override
  SyncColors lerp(SyncColors? other, double t) => other == null
      ? this
      : SyncColors(
          pending: Color.lerp(pending, other.pending, t)!,
          onPending: Color.lerp(onPending, other.onPending, t)!,
          synced: Color.lerp(synced, other.synced, t)!,
          onSynced: Color.lerp(onSynced, other.onSynced, t)!,
          failed: Color.lerp(failed, other.failed, t)!,
          onFailed: Color.lerp(onFailed, other.onFailed, t)!,
        );
}

/// A survey status as a word, an icon and a pair of the scheme's colours:
/// never colour alone (a phone in the sun, a reader who mixes red and green).
({String label, IconData icon, Color bg, Color fg}) statusLook(ColorScheme s, SurveyStatus status) =>
    switch (status) {
      SurveyStatus.not_started =>
        (label: 'Not started', icon: Icons.radio_button_unchecked, bg: s.surfaceContainerHighest, fg: s.onSurfaceVariant),
      SurveyStatus.in_progress =>
        (label: 'In progress', icon: Icons.timelapse, bg: s.secondaryContainer, fg: s.onSecondaryContainer),
      SurveyStatus.submitted =>
        (label: 'Submitted', icon: Icons.check_circle_outline, bg: s.primaryContainer, fg: s.onPrimaryContainer),
      SurveyStatus.approved =>
        (label: 'Approved', icon: Icons.verified_outlined, bg: s.tertiaryContainer, fg: s.onTertiaryContainer),
      SurveyStatus.needs_rework =>
        (label: 'Needs rework', icon: Icons.replay, bg: s.errorContainer, fg: s.onErrorContainer),
    };

/// The one shape of every state in the app: an icon and a word on a tint.
class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, required this.icon, required this.bg, required this.fg});

  final String label;
  final IconData icon;
  final Color bg, fg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: fg)),
        ]),
      );
}
