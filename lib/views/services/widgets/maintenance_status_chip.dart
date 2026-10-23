import 'package:flutter/material.dart';

/// US-17: "Scheduled", "Done" or "Cancelled".
class MaintenanceStatusChip extends StatelessWidget {
  const MaintenanceStatusChip({
    super.key,
    required this.isCancelled,
    required this.isDone,
  });

  final bool isCancelled;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (label, icon, background, foreground) = isCancelled
        ? (
            'Cancelled',
            Icons.cancel_outlined,
            colors.surfaceContainerHighest,
            colors.onSurfaceVariant,
          )
        : isDone
        ? (
            'Done',
            Icons.check_circle_outline,
            colors.primaryContainer,
            colors.onPrimaryContainer,
          )
        : (
            'Scheduled',
            Icons.event_available,
            colors.secondaryContainer,
            colors.onSecondaryContainer,
          );

    return Chip(
      avatar: Icon(icon, size: 18, color: foreground),
      label: Text(label),
      labelStyle: TextStyle(color: foreground),
      backgroundColor: background,
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}
