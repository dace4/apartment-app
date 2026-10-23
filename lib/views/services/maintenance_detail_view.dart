import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/maintenance_request.dart';
import '../../router/app_routes.dart';
import '../../utils/formatters.dart';
import '../../view_models/maintenance_detail_view_model.dart';
import '../shared/widgets/message_view.dart';
import 'widgets/maintenance_status_chip.dart';

/// US-17: one repair or maintenance service, which can be rescheduled or
/// cancelled until it starts.
class MaintenanceDetailView extends StatefulWidget {
  const MaintenanceDetailView({super.key, required this.requestId});

  final String requestId;

  @override
  State<MaintenanceDetailView> createState() => _MaintenanceDetailViewState();
}

class _MaintenanceDetailViewState extends State<MaintenanceDetailView> {
  final viewModel = MaintenanceDetailViewModel();

  @override
  void initState() {
    super.initState();
    viewModel.listenToRequest(widget.requestId);
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this service?'),
        content: const Text(
          'The time slot becomes free again. You cannot undo this.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel service'),
          ),
        ],
      ),
    );
    if (confirmed == true) viewModel.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Maintenance service')),
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
              onAction: () => viewModel.listenToRequest(widget.requestId),
            );
          }

          // 3. Not found
          final request = viewModel.request;
          if (request == null) {
            return const MessageView(
              icon: Icons.search_off,
              message: 'This maintenance service does not exist.',
            );
          }

          // 4. Data
          return _details(context, request);
        },
      ),
    );
  }

  Widget _details(BuildContext context, MaintenanceRequest request) {
    final theme = Theme.of(context);
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
              Text(request.apartmentTitle, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: MaintenanceStatusChip(
                  isCancelled: request.isCancelled,
                  isDone: viewModel.isDone,
                ),
              ),
              const SizedBox(height: 16),
              _Row('When', formatTimeSlot(request.slotStart, request.slotEnd)),
              _Row('Category', request.category.label),
              _Row('Description', request.description),
              _Row(
                'Reminders',
                request.reminders.map((reminder) => reminder.label).join(', '),
              ),
              const SizedBox(height: 16),
              Text(
                request.isCancelled
                    ? 'This service was cancelled.'
                    : canChange
                    ? 'You can reschedule or cancel until the service starts.'
                    : viewModel.isDone
                    ? 'This service is done.'
                    : 'This service is in progress.',
                style: theme.textTheme.bodyMedium,
              ),
              if (canChange) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: viewModel.isCancelling
                      ? null
                      : () => context.go(
                          AppRoutes.maintenanceReschedule(request.id),
                        ),
                  icon: const Icon(Icons.edit_calendar_outlined),
                  label: const Text('Reschedule'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: viewModel.isCancelling ? null : _cancel,
                  icon: viewModel.isCancelling
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.event_busy),
                  label: const Text('Cancel service'),
                ),
              ],
              if (viewModel.actionError != null) ...[
                const SizedBox(height: 8),
                Text(
                  viewModel.actionError!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One label and value line of the service details.
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
            width: 110,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
