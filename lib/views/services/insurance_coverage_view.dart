import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/app_routes.dart';
import '../../utils/formatters.dart';
import '../../view_models/insurance_contact_view_model.dart';
import '../shared/widgets/message_view.dart';

/// US-19: what a coverage includes and who its agent is.
class InsuranceCoverageView extends StatefulWidget {
  const InsuranceCoverageView({super.key, required this.coverageId});

  final String coverageId;

  @override
  State<InsuranceCoverageView> createState() => _InsuranceCoverageViewState();
}

class _InsuranceCoverageViewState extends State<InsuranceCoverageView> {
  final viewModel = InsuranceContactViewModel();

  @override
  void initState() {
    super.initState();
    viewModel.fetchCoverage(widget.coverageId);
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
      appBar: AppBar(title: const Text('Coverage')),
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
              onAction: () => viewModel.fetchCoverage(widget.coverageId),
            );
          }
          // 3. Not found
          final coverage = viewModel.coverage;
          if (coverage == null) {
            return MessageView(
              icon: Icons.search_off,
              message: 'This coverage is no longer offered.',
              actionLabel: 'Back to insurance',
              onAction: () => context.go(AppRoutes.insurance),
            );
          }
          // 4. Data
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(coverage.name, style: theme.textTheme.headlineSmall),
              if (coverage.priceFromChf > 0)
                Text(
                  'From ${formatChf(coverage.priceFromChf)} / month '
                  '(indicative)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              if (coverage.provider.isNotEmpty) Text(coverage.provider),
              const SizedBox(height: 16),
              if (coverage.description.isNotEmpty)
                Text(coverage.description, style: theme.textTheme.bodyLarge),
              if (coverage.covered.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('What is covered', style: theme.textTheme.titleMedium),
                for (final item in coverage.covered)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.check),
                    title: Text(item),
                  ),
              ],
              const SizedBox(height: 16),
              Text('Your agent', style: theme.textTheme.titleMedium),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(coverage.agentName),
                    ),
                    if (coverage.agentEmail.isNotEmpty)
                      ListTile(
                        leading: const Icon(Icons.email_outlined),
                        title: Text(coverage.agentEmail),
                      ),
                    if (coverage.agentPhone.isNotEmpty)
                      ListTile(
                        leading: const Icon(Icons.phone_outlined),
                        title: Text(coverage.agentPhone),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () =>
                    context.go(AppRoutes.insuranceContact(coverage.id)),
                icon: const Icon(Icons.send_outlined),
                label: const Text('Contact agent'),
              ),
            ],
          );
        },
      ),
    );
  }
}
