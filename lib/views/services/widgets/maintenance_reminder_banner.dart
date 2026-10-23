import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_routes.dart';
import '../../../utils/formatters.dart';
import '../../../view_models/maintenance_reminders_view_model.dart';

/// US-17 acceptance criterion: the in-app reminder before a scheduled
/// service. Shown above the bottom navigation, so it is visible on every
/// tab. Shows the soonest due reminder; dismissing it shows the next one.
class MaintenanceReminderBanner extends StatelessWidget {
  const MaintenanceReminderBanner({super.key, required this.viewModel});

  final MaintenanceRemindersViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final dueReminders = viewModel.dueReminders;
        if (dueReminders.isEmpty) return const SizedBox.shrink();

        final due = dueReminders.first;
        final request = due.request;
        final colors = Theme.of(context).colorScheme;

        return Material(
          color: colors.tertiaryContainer,
          child: ListTile(
            leading: Icon(
              Icons.notifications_active_outlined,
              color: colors.onTertiaryContainer,
            ),
            title: Text(
              'Reminder: ${request.category.label} at '
              '${request.apartmentTitle}',
              style: TextStyle(color: colors.onTertiaryContainer),
            ),
            subtitle: Text(
              formatTimeSlot(request.slotStart, request.slotEnd),
              style: TextStyle(color: colors.onTertiaryContainer),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              color: colors.onTertiaryContainer,
              tooltip: 'Dismiss reminder',
              onPressed: () => viewModel.dismiss(due),
            ),
            onTap: () => context.go(AppRoutes.maintenanceDetail(request.id)),
          ),
        );
      },
    );
  }
}
