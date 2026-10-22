import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/faq_entry.dart';
import '../../view_models/faq_view_model.dart';
import '../shared/widgets/message_view.dart';

/// US 14: answers to common property questions, searchable and grouped by
/// topic. Each answer can link to the page where the user can act on it.
/// Opened from an apartment, it also offers to contact its advertiser.
class FaqView extends StatefulWidget {
  const FaqView({super.key, required this.canAccess, this.apartmentId});

  final bool Function(String location) canAccess;
  final String? apartmentId;

  @override
  State<FaqView> createState() => _FaqViewState();
}

class _FaqViewState extends State<FaqView> {
  late final viewModel = FaqViewModel(
    canAccess: widget.canAccess,
    apartmentId: widget.apartmentId,
  );
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    viewModel.dispose();
    super.dispose();
  }

  void _clearFilters() {
    _searchController.clear();
    viewModel.clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FAQ')),
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          final entries = viewModel.visibleEntries;
          final contactLocation = viewModel.contactLocation;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: viewModel.search,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: 'Search the FAQ',
                    hintText: 'e.g. deposit, visit, documents',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    suffixIcon: viewModel.query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              viewModel.search('');
                            },
                          ),
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _CategoryChip(
                      label: 'All',
                      selected: viewModel.category == null,
                      onSelected: () => viewModel.selectCategory(null),
                    ),
                    for (final category in viewModel.categories)
                      _CategoryChip(
                        label: category.label,
                        selected: viewModel.category == category,
                        onSelected: () => viewModel.selectCategory(category),
                      ),
                  ],
                ),
              ),
              if (contactLocation != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.help_outline),
                      title: const Text('Question about this apartment?'),
                      subtitle: const Text(
                        'If the FAQ does not answer it, ask the advertiser.',
                      ),
                      trailing: TextButton(
                        onPressed: () => context.go(contactLocation),
                        child: const Text('Contact'),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: entries.isEmpty
                    // Empty state: says why and offers a way out.
                    ? MessageView(
                        icon: Icons.search_off,
                        message: viewModel.emptyMessage,
                        actionLabel: viewModel.hasFilters
                            ? 'Show all questions'
                            : null,
                        onAction: viewModel.hasFilters ? _clearFilters : null,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: entries.length,
                        itemBuilder: (context, index) => _FaqTile(
                          entry: entries[index],
                          linkLocation: viewModel.linkFor(entries[index]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

/// One question; tapping it shows the answer and its link.
class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.entry, required this.linkLocation});

  final FaqEntry entry;
  final String? linkLocation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: ExpansionTile(
        // Keeps each tile open or closed while the list is filtered.
        key: PageStorageKey(entry.id),
        title: Text(entry.question),
        subtitle: Text(entry.category.label, style: theme.textTheme.bodySmall),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          Text(entry.answer, style: theme.textTheme.bodyMedium),
          if (linkLocation != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => context.go(linkLocation!),
              icon: const Icon(Icons.arrow_forward),
              label: Text(entry.linkLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
