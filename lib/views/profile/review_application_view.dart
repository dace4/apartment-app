import 'package:flutter/material.dart';

import '../../models/rental_application.dart';
import '../../utils/formatters.dart';
import '../../view_models/review_application_view_model.dart';
import '../applications/widgets/application_status_chip.dart';
import '../shared/widgets/message_view.dart';

/// US 16: one received application, with the review actions.
class ReviewApplicationView extends StatefulWidget {
  const ReviewApplicationView({super.key, required this.applicationId});

  final String applicationId;

  @override
  State<ReviewApplicationView> createState() => _ReviewApplicationViewState();
}

class _ReviewApplicationViewState extends State<ReviewApplicationView> {
  final viewModel = ReviewApplicationViewModel();

  @override
  void initState() {
    super.initState();
    viewModel.fetchApplication(widget.applicationId);
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
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
              onAction: () => viewModel.fetchApplication(widget.applicationId),
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
              if (application.type == ApplicationType.immediate)
                const _Row('Type', 'Immediate application'),
              _Row('Full name', details.fullName),
              _Row('Phone', details.phone),
              _Row('Move-in date', formatDate(details.moveInDate)),
              _Row('Occupants', '${details.occupants}'),
              if (details.message.isNotEmpty) _Row('Message', details.message),
              if (application.documentIds.isNotEmpty)
                _Row('Attachments', '${application.documentIds.length}'),
              const SizedBox(height: 24),
              if (viewModel.nextSteps.isEmpty)
                const Text('No further action is possible.')
              else
                for (final status in viewModel.nextSteps)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: status == ApplicationStatus.rejected
                        ? OutlinedButton(
                            onPressed: viewModel.isSaving
                                ? null
                                : () => viewModel.review(status),
                            child: Text(_actionLabel(status)),
                          )
                        : FilledButton(
                            onPressed: viewModel.isSaving
                                ? null
                                : () => viewModel.review(status),
                            child: Text(_actionLabel(status)),
                          ),
                  ),
              if (viewModel.stepNotice != null) Text(viewModel.stepNotice!),
              if (viewModel.actionError != null)
                Text(
                  viewModel.actionError!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _actionLabel(ApplicationStatus status) => switch (status) {
    ApplicationStatus.received => 'Mark as received',
    ApplicationStatus.underReview => 'Start review',
    ApplicationStatus.accepted => 'Accept',
    ApplicationStatus.rejected => 'Reject',
    _ => status.label,
  };
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
