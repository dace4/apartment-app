import '../../view_models/auth_view_model.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/rental_application.dart';
import '../../router/app_routes.dart';
import '../../utils/formatters.dart';
import '../shared/widgets/message_view.dart';
import '../../view_models/applications_view_model.dart';
import 'widgets/application_status_chip.dart';

/// US 16: lists the user's applications with their current status.
class ApplicationsView extends StatefulWidget {
  final AuthViewModel? authViewModel;
  const ApplicationsView({this.authViewModel, super.key});

  @override
  State<ApplicationsView> createState() => _ApplicationsViewState();
}

class _ApplicationsViewState extends State<ApplicationsView> {
  late final viewModel = ApplicationsViewModel(
    canAccess: () =>
        widget.authViewModel?.canAccess(AppRoutes.applications) == true,
  );

  @override
  void initState() {
    super.initState();
    viewModel.listenToApplications();
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My applications')),
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
              onAction: viewModel.listenToApplications,
            );
          }

          // 3. Empty
          if (viewModel.applications.isEmpty) {
            return MessageView(
              icon: Icons.description_outlined,
              message: 'You have not applied for an apartment yet.',
              actionLabel: 'Browse apartments',
              onAction: () => context.go(AppRoutes.apartments),
            );
          }

          // 4. Data
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: viewModel.applications.length,
            itemBuilder: (context, index) {
              final application = viewModel.applications[index];
              return _ApplicationTile(
                application: application,
                canChange: viewModel.canChange(application),
              );
            },
          );
        },
      ),
    );
  }
}

class _ApplicationTile extends StatelessWidget {
  const _ApplicationTile({required this.application, required this.canChange});

  final RentalApplication application;
  final bool canChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(AppRoutes.applicationDetail(application.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      application.apartmentTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text('Submitted ${formatDate(application.submittedAt)}'),
                    if (canChange)
                      Text(
                        'Editable until '
                        '${formatDate(application.changeDeadline)}',
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ApplicationStatusChip(status: application.status),
            ],
          ),
        ),
      ),
    );
  }
}
