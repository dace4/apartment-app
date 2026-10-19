import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/saved_search.dart';
import '../../router/app_routes.dart';
import '../../utils/formatters.dart';
import '../../view_models/apartments_view_model.dart';
import '../../view_models/saved_searches_view_model.dart';
import '../shared/widgets/message_view.dart';

/// US 23.2: the saved searches, with a switch for the alerts of each one.
class SavedSearchesView extends StatelessWidget {
  const SavedSearchesView({
    super.key,
    required this.viewModel,
    required this.apartmentsViewModel,
  });

  /// Shared with the apartment list, which saves the searches.
  final SavedSearchesViewModel viewModel;

  /// To show the results of a search on the apartment list.
  final ApartmentsViewModel apartmentsViewModel;

  void _showResults(BuildContext context, SavedSearch search) {
    apartmentsViewModel.applyFilter(search.filter);
    context.go(AppRoutes.apartments);
  }

  Future<void> _confirmDelete(BuildContext context, SavedSearch search) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this search?'),
        content: Text('"${search.name}" will no longer alert you.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) viewModel.delete(search);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved searches')),
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
            );
          }

          // 3. Empty
          if (viewModel.searches.isEmpty) {
            return MessageView(
              icon: Icons.bookmark_border,
              message:
                  'No saved searches yet. Set filters on the Home tab, '
                  'then tap the bookmark to save them.',
              actionLabel: 'Go to search',
              onAction: () => context.go(AppRoutes.apartments),
            );
          }

          // 4. Data
          final theme = Theme.of(context);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // US 18's "New listings" switch overrides every search.
              if (!viewModel.newListingAlertsEnabled)
                Card(
                  color: theme.colorScheme.tertiaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.notifications_off_outlined),
                    title: const Text(
                      'New listing notifications are switched off, so no '
                      'alert is shown.',
                    ),
                    trailing: TextButton(
                      onPressed: () => context.go(AppRoutes.notifications),
                      child: const Text('Settings'),
                    ),
                  ),
                ),
              if (viewModel.actionError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    viewModel.actionError!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              for (final search in viewModel.searches)
                _SavedSearchCard(
                  search: search,
                  onAlertsChanged: (enabled) =>
                      viewModel.setAlertsEnabled(search, enabled),
                  onShowResults: () => _showResults(context, search),
                  onDelete: () => _confirmDelete(context, search),
                ),
              const SizedBox(height: 8),
              Text(
                '${viewModel.searches.length}/${SavedSearch.maxPerUser} '
                'saved searches',
                style: theme.textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One saved search: its name, criteria, alert switch and actions.
class _SavedSearchCard extends StatelessWidget {
  const _SavedSearchCard({
    required this.search,
    required this.onAlertsChanged,
    required this.onShowResults,
    required this.onDelete,
  });

  final SavedSearch search;
  final ValueChanged<bool> onAlertsChanged;
  final VoidCallback onShowResults;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(search.name, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(describeFilter(search.filter)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Alerts for new offers'),
              value: search.alertsEnabled,
              onChanged: onAlertsChanged,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: onShowResults,
                  child: const Text('Show results'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
