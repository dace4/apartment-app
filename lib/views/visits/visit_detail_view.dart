import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/app_routes.dart';
import '../../utils/formatters.dart';
import '../../view_models/visit_detail_view_model.dart';
import '../shared/widgets/message_view.dart';

/// US-20: for the owner, who wants to visit which apartment and when.
class VisitDetailView extends StatefulWidget {
  const VisitDetailView({super.key, required this.visitId});

  final String visitId;

  @override
  State<VisitDetailView> createState() => _VisitDetailViewState();
}

class _VisitDetailViewState extends State<VisitDetailView> {
  final viewModel = VisitDetailViewModel();

  @override
  void initState() {
    super.initState();
    viewModel.listenToVisit(widget.visitId);
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Visit')),
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
              onAction: () => viewModel.listenToVisit(widget.visitId),
            );
          }
          // 3. Not found
          final visit = viewModel.visit;
          if (visit == null) {
            return const MessageView(
              icon: Icons.search_off,
              message: 'This visit does not exist.',
            );
          }
          // 4. Data
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.event),
                      title: Text(
                        formatTimeSlot(visit.slotStart, visit.slotEnd),
                      ),
                      subtitle: const Text('Date and time'),
                      trailing: Chip(label: Text(viewModel.statusLabel)),
                    ),
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(visit.visitorEmail),
                      subtitle: const Text('Visitor'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.home_outlined),
                      title: Text(visit.apartmentTitle),
                      subtitle: const Text('Apartment'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go(
                        AppRoutes.apartmentDetail(visit.apartmentId),
                      ),
                    ),
                  ],
                ),
              ),
              if (visit.isCancelled)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'The visitor cancelled this visit. The time slot is free '
                    'again.',
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
