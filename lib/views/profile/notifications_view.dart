import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/app_notification.dart';
import '../../router/app_routes.dart';
import '../../view_models/notifications_view_model.dart';

/// US 18: opt-in / opt-out switches and the list of notifications.
class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key});

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  // Only this screen needs the notifications, so it owns its ViewModel
  // (ARCHITECTURE.md §4).
  final viewModel = NotificationsViewModel();

  @override
  void initState() {
    super.initState();
    viewModel.listen();
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
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
              // Acceptance criterion: opt in / opt out at any time.
              Text(
                'Receive notifications about',
                style: theme.textTheme.titleMedium,
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
                    onTap: () {
                      viewModel.markAsRead(notification);
                      // US 23: a new-offer alert opens its apartment.
                      final apartmentId = notification.apartmentId;
                      if (apartmentId != null) {
                        context.go(AppRoutes.apartmentDetail(apartmentId));
                      }
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
