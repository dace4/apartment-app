import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_routes.dart';
import '../../../shared/widgets/message_view.dart';
import '../data/apartment_repository.dart';
import '../models/apartment.dart';
import '../models/apartment_filter.dart';
import '../widgets/apartment_card.dart';

class ApartmentListPage extends StatefulWidget {
  const ApartmentListPage({
    super.key,
    this.repository = const ApartmentRepository(),
  });

  final ApartmentRepository repository;

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
            icon: const Icon(Icons.tune),
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
                        MessageView(
                          icon: Icons.search_off,
                          message: _availability == null && _filter.isEmpty
                              ? 'No apartments available right now.'
                              : 'No results found.',
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
                      return ApartmentCard(
                        key: ValueKey(apartment.id),
                        apartment: apartment,
                        onTap: () =>
                            context.go(AppRoutes.apartmentDetail(apartment.id)),
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
