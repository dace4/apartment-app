import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_routes.dart';
import '../../../shared/widgets/message_view.dart';
import '../../comparison/view_models/comparison_view_model.dart';
import '../data/apartment_repository.dart';
import '../models/apartment.dart';
import '../models/apartment_filter.dart';
import '../widgets/apartment_card.dart';

class ApartmentListPage extends StatefulWidget {
  const ApartmentListPage({
    super.key,
    this.repository = const ApartmentRepository(),
    this.comparison,
  });

  final ApartmentRepository repository;

  //US13
  final ComparisonViewModel? comparison;

  @override
  State<ApartmentListPage> createState() => _ApartmentListPageState();
}

class _ApartmentListPageState extends State<ApartmentListPage> {
  // Keep the stream outside build() so selecting a filter does not reconnect it.
  late Stream<List<Apartment>> _apartments;
  // null represents All; the filter only affects the visible list, not its data.
  ApartmentAvailability? _availability;
  // US 5: criteria from the Filters page, combined with the availability.
  ApartmentFilter _filter = const ApartmentFilter();
  bool _refreshing = false;

  late final ComparisonViewModel _comparison =
      widget.comparison ?? ComparisonViewModel();

  @override
  void initState() {
    super.initState();
    _apartments = widget.repository.watchApartments();
  }

  void _reload() {
    setState(() {
      _apartments = widget.repository.watchApartments();
    });
  }

  /// Opens the Filters page pre-filled with the active filter, and keeps the
  /// filter it returns. Leaving the page with Back returns null: no change.
  Future<void> _openFilters() async {
    final filter = await context.push<ApartmentFilter>(
      AppRoutes.filters,
      extra: _filter,
    );
    if (filter != null && mounted) setState(() => _filter = filter);
  }

  /// Removes every filter, including the availability one, from the
  /// no-results state so the user is never stuck on an empty list.
  void _clearFilters() {
    setState(() {
      _filter = const ApartmentFilter();
      _availability = null;
    });
  }

  ///US13 add or remove an apartment + explain a reject selection
  void _toggleCompare(Apartment apartment) {
    final message = switch (_comparison.toggle(apartment)) {
      SelectionResult.limitReached => 'You can compare up to 2 apartments',
      SelectionResult.differentListingType =>
        'Only apartment of the same type (rent or sales) can be compared. ',
      SelectionResult.added || SelectionResult.removed => null,
    };
    if (message == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _refresh() async {
    // Pull-to-refresh and the toolbar share this guard against parallel requests.
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await widget.repository.fetchApartments().timeout(
        const Duration(seconds: 12),
      );
      // Reconnect after a successful repository read, retaining the selected filter.
      if (mounted) _reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not refresh availability. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Apartments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh availability',
            onPressed: _refreshing ? null : _refresh,
          ),
          IconButton(
            // The badge shows how many criteria are active.
            icon: Badge(
              isLabelVisible: !_filter.isEmpty,
              label: Text('${_filter.activeCount}'),
              child: const Icon(Icons.tune),
            ),
            tooltip: 'Filters',
            onPressed: _openFilters,
          ),
          IconButton(
            icon: const Icon(Icons.compare_arrows),
            tooltip: 'Compare',
            onPressed: () => context.go(AppRoutes.compare),
          ),
        ],
      ),

      //US13 : show the selection and compare button once 1 is picked
      bottomNavigationBar: ListenableBuilder(
        listenable: _comparison,
        builder: (context, _) {
          if (_comparison.count == 0) return const SizedBox.shrink();
          return Material(
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_comparison.count}/${ComparisonViewModel.maxSelection} selected',
                    ),
                  ),
                  TextButton(
                    onPressed: _comparison.clear,
                    child: const Text('Clear'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _comparison.canCompare
                        ? () => context.go(AppRoutes.compare)
                        : null,
                    child: const Text('Compare'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _availability == null,
                  onSelected: (_) => setState(() => _availability = null),
                ),
                for (final status in ApartmentAvailability.values)
                  ChoiceChip(
                    label: Text(status.label),
                    selected: _availability == status,
                    onSelected: (_) => setState(() => _availability = status),
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Apartment>>(
              stream: _apartments,
              builder: (context, snapshot) {
                // 1. Loading
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // 2. Error
                if (snapshot.hasError) {
                  return MessageView(
                    icon: Icons.cloud_off,
                    message: 'Could not load the apartments.',
                    actionLabel: 'Retry',
                    onAction: _reload,
                  );
                }

                // Reapply the active filter on every snapshot so a property that
                // becomes reserved immediately leaves an Available-only list.
                final apartments = (snapshot.data ?? <Apartment>[])
                    .where(
                      (apartment) =>
                          (_availability == null ||
                              apartment.availability == _availability) &&
                          _filter.matches(apartment),
                    )
                    .toList();
                if (apartments.isEmpty) {
                  // A scrollable empty state still permits pull-to-refresh.
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 80),
                        if (_availability == null && _filter.isEmpty)
                          const MessageView(
                            icon: Icons.search_off,
                            message: 'No apartments available right now.',
                          )
                        else
                          // US 5: listings exist, but none match the filters.
                          MessageView(
                            icon: Icons.filter_alt_off_outlined,
                            message: 'No results found.',
                            actionLabel: 'Clear filters',
                            onAction: _clearFilters,
                          ),
                      ],
                    ),
                  );
                }

                // 4. Data
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(8),
                    itemCount: apartments.length,
                    itemBuilder: (context, index) {
                      final apartment = apartments[index];

                      //US13
                      return ListenableBuilder(
                        listenable: _comparison,
                        builder: (context, _) => ApartmentCard(
                          key: ValueKey(apartment.id),
                          apartment: apartment,
                          onTap: () => context.go(
                            AppRoutes.apartmentDetail(apartment.id),
                          ),
                          isSelectedForCompare: _comparison.isSelected(
                            apartment,
                          ),
                          onCompare: () => _toggleCompare(apartment),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
