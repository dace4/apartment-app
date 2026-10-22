import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/visit.dart';
import '../../router/app_routes.dart';
import '../../utils/formatters.dart';
import '../../view_models/my_visits_view_model.dart';
import '../shared/widgets/message_view.dart';

/// US-20: the visits the user booked; upcoming ones can be cancelled.
class MyVisitsView extends StatefulWidget {
  const MyVisitsView({super.key});

  @override
  State<MyVisitsView> createState() => _MyVisitsViewState();
}

class _MyVisitsViewState extends State<MyVisitsView> {
  final viewModel = MyVisitsViewModel();

  @override
  void initState() {
    super.initState();
    viewModel.listenToVisits();
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  Future<void> _cancel(Visit visit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this visit?'),
        content: Text(
          '${visit.apartmentTitle}\n'
          '${formatTimeSlot(visit.slotStart, visit.slotEnd)}\n\n'
          'The owner will be notified and the time slot becomes free again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep visit'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel visit'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final cancelled = await viewModel.cancel(visit);
    if (cancelled && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Visit cancelled.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('My visits')),
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
              onAction: viewModel.listenToVisits,
            );
          }
          // 3. Empty
          if (viewModel.isEmpty) {
            return MessageView(
              icon: Icons.event_outlined,
              message:
                  'No visits booked yet. Open an apartment and tap '
                  'Schedule a visit.',
              actionLabel: 'Browse apartments',
              onAction: () => context.go(AppRoutes.apartments),
            );
          }
          // 4. Data
          final upcoming = viewModel.upcoming;
          final past = viewModel.past;
          return ListView(
            padding: const EdgeInsets.all(8),
            children: [
              if (viewModel.actionError != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    viewModel.actionError!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              if (upcoming.isNotEmpty) ...[
                const _SectionTitle('Upcoming'),
                for (final visit in upcoming)
                  _VisitTile(
                    visit: visit,
                    trailing: viewModel.canCancel(visit)
                        ? TextButton(
                            onPressed: viewModel.cancellingId == null
                                ? () => _cancel(visit)
                                : null,
                            child: Text(
                              viewModel.cancellingId == visit.id
                                  ? 'Cancelling…'
                                  : 'Cancel',
                            ),
                          )
                        : const Text('In progress'),
                  ),
              ],
              if (past.isNotEmpty) ...[
                const _SectionTitle('Past & cancelled'),
                for (final visit in past)
                  _VisitTile(
                    visit: visit,
                    trailing: Text(visit.isCancelled ? 'Cancelled' : 'Done'),
                  ),
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

class _VisitTile extends StatelessWidget {
  const _VisitTile({required this.visit, required this.trailing});

  final Visit visit;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.event_outlined),
        title: Text(visit.apartmentTitle),
        subtitle: Text(formatTimeSlot(visit.slotStart, visit.slotEnd)),
        trailing: trailing,
        onTap: () => context.go(AppRoutes.apartmentDetail(visit.apartmentId)),
      ),
    );
  }
}
