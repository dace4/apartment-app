import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/rental_application.dart';
import '../../router/app_routes.dart';
import '../../utils/formatters.dart';
import '../shared/widgets/message_view.dart';
import '../../view_models/application_detail_view_model.dart';
import 'widgets/application_status_chip.dart';

/// US 16: shows one application and lets the user edit or withdraw it
/// within 5 days of submitting.
class ApplicationDetailView extends StatefulWidget {
  const ApplicationDetailView({super.key, required this.applicationId});

  final String applicationId;

  @override
  State<ApplicationDetailView> createState() => _ApplicationDetailViewState();
}

class _ApplicationDetailViewState extends State<ApplicationDetailView> {
  final viewModel = ApplicationDetailViewModel();

  @override
  void initState() {
    super.initState();
    viewModel.listenToApplication(widget.applicationId);
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  Future<void> _withdraw() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw application?'),
        content: const Text(
          'The advertiser will no longer consider this application. '
          'You cannot undo this.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (confirmed == true) viewModel.withdraw();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Application')),
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
              onAction: () =>
                  viewModel.listenToApplication(widget.applicationId),
            );
          }

          // 3. Not found
          final application = viewModel.application;
          if (application == null) {
            return const MessageView(
              icon: Icons.search_off,
              message: 'This application does not exist.',
            );
          }

          // 4. Data
          return _details(context, application);
        },
      ),
    );
  }

  Widget _details(BuildContext context, RentalApplication application) {
    final theme = Theme.of(context);
    final details = application.details;
    final canChange = viewModel.canChange;

    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                application.apartmentTitle,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: ApplicationStatusChip(status: application.status),
              ),
              const SizedBox(height: 16),
              _Row('Submitted', formatDate(application.submittedAt)),
              _Row('Full name', details.fullName),
              _Row('Phone', details.phone),
              _Row('Move-in date', formatDate(details.moveInDate)),
              _Row('Occupants', '${details.occupants}'),
              if (details.message.isNotEmpty) _Row('Message', details.message),
              const SizedBox(height: 16),
              Text(
                _changeInfo(application, canChange),
                style: theme.textTheme.bodyMedium,
              ),
              if (canChange) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: viewModel.isWithdrawing
                      ? null
                      : () => context.go(
                          AppRoutes.editApplication(application.id),
                        ),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: viewModel.isWithdrawing ? null : _withdraw,
                  icon: viewModel.isWithdrawing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.undo),
                  label: const Text('Withdraw'),
                ),
                if (viewModel.withdrawError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    viewModel.withdrawError!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go(
                  AppRoutes.apartmentDetail(application.apartmentId),
                ),
                child: const Text('View apartment'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _changeInfo(RentalApplication application, bool canChange) {
    if (canChange) {
      return 'You can edit or withdraw this application until '
          '${formatDate(application.changeDeadline)}.';
    }
    return switch (application.status) {
      ApplicationStatus.withdrawn => 'You withdrew this application.',
      ApplicationStatus.accepted => 'Your application was accepted.',
      ApplicationStatus.rejected => 'Your application was not accepted.',
      ApplicationStatus.submitted || ApplicationStatus.underReview =>
        'The 5 days to edit or withdraw this application have passed.',
    };
  }
}

/// One label and value line of the application details.
class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
