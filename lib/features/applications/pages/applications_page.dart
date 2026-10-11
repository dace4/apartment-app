import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_routes.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/message_view.dart';
import '../data/application_repository.dart';
import '../models/rental_application.dart';
import '../widgets/application_status_chip.dart';

/// US 16: lists the user's applications with their current status.
class ApplicationsPage extends StatefulWidget {
  const ApplicationsPage({
    super.key,
    this.repository = const UnconfiguredApplicationRepository(),
  });

  final ApplicationRepository repository;

  @override
  State<ApplicationsPage> createState() => _ApplicationsPageState();
}

class _ApplicationsPageState extends State<ApplicationsPage> {
  // Started once, so rebuilding the page does not open a second listener.
  late Stream<List<RentalApplication>> _applications;

  @override
  void initState() {
    super.initState();
    _applications = widget.repository.watchMyApplications();
  }

  void _reload() {
    setState(() => _applications = widget.repository.watchMyApplications());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My applications')),
      body: StreamBuilder<List<RentalApplication>>(
        stream: _applications,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            final error = snapshot.error;
            return MessageView(
              icon: Icons.cloud_off,
              message: error is ApplicationException
                  ? error.message
                  : 'Could not load your applications.',
              actionLabel: 'Retry',
              onAction: _reload,
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final applications = snapshot.requireData;
          if (applications.isEmpty) {
            return MessageView(
              icon: Icons.description_outlined,
              message: 'You have not applied for an apartment yet.',
              actionLabel: 'Browse apartments',
              onAction: () => context.go(AppRoutes.apartments),
            );
          }

          final now = DateTime.now();
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: applications.length,
            itemBuilder: (context, index) {
              final application = applications[index];
              return _ApplicationTile(application: application, now: now);
            },
          );
        },
      ),
    );
  }
}

class _ApplicationTile extends StatelessWidget {
  const _ApplicationTile({required this.application, required this.now});

  final RentalApplication application;
  final DateTime now;

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
                    if (application.canChange(now))
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
