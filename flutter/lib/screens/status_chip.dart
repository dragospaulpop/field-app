import 'package:flutter/material.dart';

import '../contract/contract.dart';
import '../theme/app_theme.dart';

/// A survey's status: the theme's word, icon and colours (step 2).
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final SurveyStatus status;

  @override
  Widget build(BuildContext context) {
    final look = statusLook(Theme.of(context).colorScheme, status);
    return Pill(label: look.label, icon: look.icon, bg: look.bg, fg: look.fg);
  }
}
