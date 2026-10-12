import 'package:flutter/material.dart';

import '../../../models/rental_application.dart';

/// Shows an application's status with a colour and icon per state.
class ApplicationStatusChip extends StatelessWidget {
  const ApplicationStatusChip({super.key, required this.status});

  final ApplicationStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (icon, background, foreground) = switch (status) {
      ApplicationStatus.submitted => (
        Icons.send_outlined,
        colors.secondaryContainer,
        colors.onSecondaryContainer,
      ),
      ApplicationStatus.underReview => (
        Icons.hourglass_top,
        colors.tertiaryContainer,
        colors.onTertiaryContainer,
      ),
      ApplicationStatus.accepted => (
        Icons.check_circle_outline,
        colors.primaryContainer,
        colors.onPrimaryContainer,
      ),
      ApplicationStatus.rejected => (
        Icons.cancel_outlined,
        colors.errorContainer,
        colors.onErrorContainer,
      ),
      ApplicationStatus.withdrawn => (
        Icons.undo,
        colors.surfaceContainerHighest,
        colors.onSurfaceVariant,
      ),
    };

    return Chip(
      avatar: Icon(icon, size: 18, color: foreground),
      label: Text(status.label),
      labelStyle: TextStyle(color: foreground),
      backgroundColor: background,
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}
