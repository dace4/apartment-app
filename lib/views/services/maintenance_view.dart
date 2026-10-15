import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/maintenance_request.dart';
import '../../router/app_routes.dart';
import '../../utils/formatters.dart';
import '../../view_models/maintenance_view_model.dart';
import '../shared/widgets/message_view.dart';
import 'widgets/maintenance_status_chip.dart';

/// US-17: the user's repair and maintenance services.
class MaintenanceView extends StatefulWidget {
  const MaintenanceView({super.key});

  @override
  State<MaintenanceView> createState() => _MaintenanceViewState();
}

class _MaintenanceViewState extends State<MaintenanceView> {
  final viewModel = MaintenanceViewModel();

  @override
  void initState() {
    super.initState();
    viewModel.listenToRequests();
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Repair & maintenance')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(AppRoutes.maintenanceNew),
        icon: const Icon(Icons.add),
        label: const Text('Schedule service'),
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
              onAction: viewModel.listenToRequests,
            );
          }

          // 3. Empty
          if (viewModel.requests.isEmpty) {
            // The floating button is the only way to schedule a service.
            return const MessageView(
              icon: Icons.home_repair_service_outlined,
              message: 'No maintenance scheduled yet.',
            );
          }

          // 4. Data
          final upcoming = viewModel.upcoming;
          final past = viewModel.past;
          return ListView(
            // Room for the floating button below the last card.
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
            children: [
              if (upcoming.isNotEmpty) ...[
                const _SectionTitle('Upcoming'),
                for (final request in upcoming) _RequestTile(request),
              ],
              if (past.isNotEmpty) ...[
                const _SectionTitle('Past & cancelled'),
                for (final request in past) _RequestTile(request),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile(this.request);

  final MaintenanceRequest request;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text('${request.category.label} · ${request.apartmentTitle}'),
        subtitle: Text(formatTimeSlot(request.slotStart, request.slotEnd)),
        trailing: MaintenanceStatusChip(
          isCancelled: request.isCancelled,
          isDone: request.isDone(DateTime.now()),
        ),
        onTap: () => context.go(AppRoutes.maintenanceDetail(request.id)),
      ),
    );
  }
}
