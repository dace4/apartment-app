import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/insurance_coverage.dart';
import '../../models/insurance_request.dart';
import '../../router/app_routes.dart';
import '../../utils/formatters.dart';
import '../../view_models/insurance_view_model.dart';
import '../shared/widgets/message_view.dart';

/// US-19: the insurance coverages a renter can choose from, and the
/// requests they sent to agents.
class InsuranceView extends StatefulWidget {
  const InsuranceView({super.key});

  @override
  State<InsuranceView> createState() => _InsuranceViewState();
}

class _InsuranceViewState extends State<InsuranceView> {
  final viewModel = InsuranceViewModel();

  @override
  void initState() {
    super.initState();
    viewModel.fetchCoverages();
    viewModel.listenToRequests();
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
      appBar: AppBar(title: const Text('Insurance')),
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
              onAction: viewModel.fetchCoverages,
            );
          }
          // 3. Empty
          if (viewModel.coverages.isEmpty) {
            return const MessageView(
              icon: Icons.shield_outlined,
              message: 'No insurance coverages are available yet.',
            );
          }
          // 4. Data
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Protect your belongings and meet your landlord\'s '
                'requirements. Choose a coverage to see the details and '
                'contact its agent.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              for (final coverage in viewModel.coverages)
                _CoverageCard(coverage: coverage),
              const SizedBox(height: 24),
              Text('My requests', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              if (viewModel.requestsError != null)
                Text(
                  viewModel.requestsError!,
                  style: TextStyle(color: theme.colorScheme.error),
                )
              else if (viewModel.requests.isEmpty)
                const Text('You have not contacted an agent yet.')
              else
                for (final request in viewModel.requests)
                  _RequestTile(request: request),
            ],
          );
        },
      ),
    );
  }
}

class _CoverageCard extends StatelessWidget {
  const _CoverageCard({required this.coverage});

  final InsuranceCoverage coverage;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.shield_outlined),
        title: Text(coverage.name),
        subtitle: Text(
          [
            if (coverage.summary.isNotEmpty) coverage.summary,
            if (coverage.priceFromChf > 0)
              'From ${formatChf(coverage.priceFromChf)} / month',
          ].join('\n'),
        ),
        isThreeLine: coverage.summary.isNotEmpty && coverage.priceFromChf > 0,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go(AppRoutes.insuranceCoverage(coverage.id)),
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.request});

  final InsuranceRequest request;

  @override
  Widget build(BuildContext context) {
    final sentAt = request.createdAt;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.mark_email_read_outlined),
        title: Text(request.coverageName),
        subtitle: Text(
          '${sentAt == null ? 'Sending…' : 'Sent ${formatDate(sentAt)}'}'
          ' to ${request.agentName} · answer by '
          '${request.contactMethod.label.toLowerCase()}',
        ),
      ),
    );
  }
}
