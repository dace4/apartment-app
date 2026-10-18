import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/apartment.dart';
import '../../router/app_routes.dart';
import '../../utils/formatters.dart';
import '../shared/widgets/message_view.dart';
import '../../view_models/apartments_view_model.dart';
import '../../view_models/compare_view_model.dart';
import '../../view_models/favourites_view_model.dart';
import '../../view_models/saved_searches_view_model.dart';
import 'widgets/apartment_card.dart';
import 'widgets/save_search_dialog.dart';

class ApartmentsView extends StatefulWidget {
  const ApartmentsView({
    super.key,
    required this.viewModel,
    required this.compareViewModel,
    required this.favouritesViewModel,
    this.savedSearchesViewModel,
    this.title = 'Apartments',
    this.emptyMessage = 'No apartments available right now.',
  });

  /// US 23: shows the "Save this search" button when given.
  final SavedSearchesViewModel? savedSearchesViewModel;

  /// Shared with the Filters page.
  final ApartmentsViewModel viewModel;
  final FavouritesViewModel favouritesViewModel;
  final String title;
  final String emptyMessage;

  /// US 13: shared with the apartment details and the Compare page.
  final CompareViewModel compareViewModel;

  @override
  State<ApartmentsView> createState() => _ApartmentsViewState();
}

class _ApartmentsViewState extends State<ApartmentsView> {
  ApartmentsViewModel get viewModel => widget.viewModel;
  CompareViewModel get compareViewModel => widget.compareViewModel;

  @override
  void initState() {
    super.initState();
    // The ViewModel can be shared with other screens that listen to it.
    // Loading after the first frame avoids notifying them during this build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) viewModel.fetchApartments();
    });
  }

  void _toggleCompare(Apartment apartment) {
    final done = compareViewModel.toggle(apartment);
    if (!done) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can compare up to two apartments.')),
      );
    }
  }

  /// US 23.2: saves the active filters to be alerted of new offers.
  Future<void> _saveSearch() async {
    final savedSearches = widget.savedSearchesViewModel!;
    final name = await showDialog<String>(
      context: context,
      builder: (context) =>
          SaveSearchDialog(description: describeFilter(viewModel.filter)),
    );
    if (name == null || !mounted) return;

    final saved = await savedSearches.save(name, viewModel.filter);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Search saved. New matching offers will alert you.'
              : savedSearches.actionError!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      // Rebuilds when the apartments or the comparison selection change.
      listenable: Listenable.merge([
        viewModel,
        compareViewModel,
        widget.favouritesViewModel,
      ]),
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.title),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: viewModel.isLoading
                    ? null
                    : viewModel.fetchApartments,
              ),
              IconButton(
                // The badge shows how many criteria are active.
                icon: Badge(
                  isLabelVisible: !viewModel.filter.isEmpty,
                  label: Text('${viewModel.filter.activeCount}'),
                  child: const Icon(Icons.tune),
                ),
                tooltip: 'Filters',
                onPressed: () => context.go(AppRoutes.filters),
              ),
              if (widget.savedSearchesViewModel != null &&
                  compareViewModel.allowed)
                IconButton(
                  icon: const Icon(Icons.bookmark_add_outlined),
                  tooltip: 'Save this search',
                  // A search without any criterion would match every offer.
                  onPressed: viewModel.filter.isEmpty ? null : _saveSearch,
                ),
              if (compareViewModel.allowed)
                IconButton(
                  // US 13: the badge shows how many apartments are selected.
                  icon: Badge(
                    isLabelVisible: compareViewModel.selected.isNotEmpty,
                    label: Text('${compareViewModel.selected.length}'),
                    child: const Icon(Icons.compare_arrows),
                  ),
                  tooltip: 'Compare',
                  onPressed: () => context.go(AppRoutes.compare),
                ),
            ],
          ),
          body: Column(
            children: [
              _AvailabilityChips(viewModel: viewModel),
              Expanded(child: _buildList()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildList() {
    // 1. Loading (only the first time: a refresh keeps the list visible)
    if (viewModel.isLoading && viewModel.apartments.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // 2. Error
    if (viewModel.errorMessage != null) {
      return MessageView(
        icon: Icons.cloud_off,
        message: viewModel.errorMessage!,
        actionLabel: 'Retry',
        onAction: viewModel.fetchApartments,
      );
    }

    // 3. Empty
    final apartments = viewModel.visibleApartments;
    if (apartments.isEmpty) {
      return viewModel.hasFilters
          ? MessageView(
              icon: Icons.filter_alt_off_outlined,
              message: 'No results found.',
              actionLabel: 'Clear filters',
              onAction: viewModel.clearFilters,
            )
          : MessageView(icon: Icons.search_off, message: widget.emptyMessage);
    }

    // 4. Data
    return RefreshIndicator(
      onRefresh: viewModel.fetchApartments,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: apartments.length,
        itemBuilder: (context, index) {
          final apartment = apartments[index];
          return ApartmentCard(
            apartment: apartment,
            favouritesViewModel: widget.favouritesViewModel,
            onTap: () => context.go(AppRoutes.apartmentDetail(apartment.id)),
            isSelectedForCompare: compareViewModel.isSelected(apartment),
            onCompare: compareViewModel.allowed
                ? () => _toggleCompare(apartment)
                : null,
          );
        },
      ),
    );
  }
}

/// "All / Available / Reserved / Unavailable" chips above the list.
class _AvailabilityChips extends StatelessWidget {
  const _AvailabilityChips({required this.viewModel});

  final ApartmentsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        spacing: 8,
        children: [
          ChoiceChip(
            label: const Text('All'),
            selected: viewModel.availability == null,
            onSelected: (_) => viewModel.selectAvailability(null),
          ),
          for (final status in ApartmentAvailability.values)
            ChoiceChip(
              label: Text(status.label),
              selected: viewModel.availability == status,
              onSelected: (_) => viewModel.selectAvailability(status),
            ),
        ],
      ),
    );
  }
}
