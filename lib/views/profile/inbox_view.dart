import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/rental_application.dart';
import '../../router/app_routes.dart';
import '../../utils/formatters.dart';
import '../../view_models/auth_view_model.dart';
import '../../view_models/inbox_view_model.dart';
import '../applications/widgets/application_status_chip.dart';
import '../shared/widgets/message_view.dart';

/// US 16 / US 12: the applications and messages received for the user's
/// apartments, in two tabs.
class InboxView extends StatefulWidget {
  const InboxView({super.key, required this.authViewModel});

  final AuthViewModel authViewModel;

  @override
  State<InboxView> createState() => _InboxViewState();
}

class _InboxViewState extends State<InboxView> {
  late final viewModel = InboxViewModel(() => widget.authViewModel.user);

  @override
  void initState() {
    super.initState();
    viewModel.fetchInbox();
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  Future<void> _open(String location) async {
    await context.push(location);
    // An application's status may have changed on the detail page.
    if (mounted) viewModel.fetchInbox();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Inbox'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: viewModel.fetchInbox,
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Applications'),
              Tab(text: 'Messages'),
            ],
          ),
        ),
        body: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) {
            // 1. Loading
            if (viewModel.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            // 2. Error
            if (viewModel.errorMessage != null) {
              return MessageView(
                icon: Icons.cloud_off,
                message: viewModel.errorMessage!,
                actionLabel: 'Retry',
                onAction: viewModel.fetchInbox,
              );
            }

            // 3. Empty and 4. Data, for each tab
            return TabBarView(children: [_applications(), _messages()]);
          },
        ),
      ),
    );
  }

  Widget _applications() {
    if (viewModel.applications.isEmpty) {
      return const MessageView(
        icon: Icons.inbox_outlined,
        message: 'No applications for your apartments yet.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: viewModel.applications.length,
      itemBuilder: (context, index) {
        final application = viewModel.applications[index];
        return Card(
          child: ListTile(
            title: Text(application.apartmentTitle),
            subtitle: Text(
              '${application.details.fullName} · '
              '${formatDate(application.submittedAt)}'
              '${application.type == ApplicationType.immediate ? ' · Immediate' : ''}',
            ),
            trailing: ApplicationStatusChip(status: application.status),
            onTap: () => _open(AppRoutes.inboxApplication(application.id)),
          ),
        );
      },
    );
  }

  Widget _messages() {
    if (viewModel.messages.isEmpty) {
      return const MessageView(
        icon: Icons.mail_outline,
        message: 'No messages about your apartments yet.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: viewModel.messages.length,
      itemBuilder: (context, index) {
        final message = viewModel.messages[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.mail_outline),
            title: Text(message.subject),
            subtitle: Text(
              '${viewModel.apartmentTitles[message.apartmentId] ?? ''}\n'
              '${message.senderEmail}',
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _open(AppRoutes.inboxMessage(message.id)),
          ),
        );
      },
    );
  }
}
