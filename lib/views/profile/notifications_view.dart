import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/app_notification.dart';
import '../../view_models/notifications_view_model.dart';

/// US 18: opt-in / opt-out switches and the list of notifications.
class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key, required this.viewModel});

  /// Shared with the red dots on the Profile tab and tile (US-20), so it is
  /// created once in app.dart (ARCHITECTURE.md §4).
  final NotificationsViewModel viewModel;

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  NotificationsViewModel get viewModel => widget.viewModel;

  @override
  void initState() {
    super.initState();
    // Opening the page retries after a loading error.
    if (viewModel.errorMessage != null) viewModel.listen();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          // 1. Loading
          if (viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          // 2. Error
          if (viewModel.errorMessage != null) {
            return Center(child: Text(viewModel.errorMessage!));
          }

          final notifications = viewModel.notifications;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Acceptance criterion: opt in / opt out at any time. Since the
              // Sprint 3 review, the switches only control the alerts: the
              // inbox below always shows everything.
              Text('Alert me about', style: theme.textTheme.titleMedium),
              Text(
                'Every notification always appears in your inbox below. '
                'Switch a kind off to stop its alerts (the red badge).',
                style: theme.textTheme.bodySmall,
              ),
              for (final type in NotificationType.values)
                SwitchListTile(
                  title: Text(type.label),
                  value: viewModel.preferences.isEnabled(type),
                  onChanged: (enabled) => viewModel.setEnabled(type, enabled),
                ),
              if (viewModel.actionError != null)
                Text(
                  viewModel.actionError!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              const Divider(height: 32),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Inbox (${viewModel.unreadCount} unread)',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: viewModel.unreadCount == 0
                        ? null
                        : viewModel.markAllAsRead,
                    child: const Text('Mark all as read'),
                  ),
                ],
              ),
              // 3. Empty
              if (notifications.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No notifications yet.')),
                )
              // 4. Data
              else
                for (final notification in notifications)
                  _NotificationTile(
                    notification: notification,
                    // US 18.4: marks it as read and opens its page.
                    onTap: () {
                      final destination = viewModel.open(notification);
                      if (destination != null) context.go(destination);
                    },
                  ),
            ],
          );
        },
      ),
    );
  }
}

/// One notification; unread ones are bold with a coloured icon.
class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  IconData get _icon => switch (notification.type) {
    NotificationType.newListing => Icons.home_outlined,
    NotificationType.applicationStatus => Icons.assignment_outlined,
    NotificationType.announcement => Icons.campaign_outlined,
    NotificationType.visit => Icons.event_available,
    NotificationType.message => Icons.mail_outline,
    NotificationType.newApplication => Icons.inbox_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = notification.createdAt;
    final unread = !notification.isRead;

    return Card(
      child: ListTile(
        leading: Icon(_icon, color: unread ? theme.colorScheme.primary : null),
        title: Text(
          notification.title,
          style: unread ? const TextStyle(fontWeight: FontWeight.bold) : null,
        ),
        subtitle: Text(
          '${notification.body}\n${date.day}.${date.month}.${date.year}',
        ),
        isThreeLine: true,
        onTap: onTap,
      ),
    );
  }
}
