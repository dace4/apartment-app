import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/apartment.dart';
import '../../router/app_routes.dart';
import '../shared/widgets/message_view.dart';
import '../../view_models/apartments_view_model.dart';
import 'widgets/apartment_card.dart';

class ApartmentsView extends StatefulWidget {
  const ApartmentsView({super.key, required this.viewModel});

  /// Shared with the Filters page.
  final ApartmentsViewModel viewModel;

  @override
  State<ApartmentsView> createState() => _ApartmentsViewState();
}

class _ApartmentsViewState extends State<ApartmentsView> {
  ApartmentsViewModel get viewModel => widget.viewModel;

  @override
  void initState() {
    super.initState();
    viewModel.fetchApartments();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Apartments'),
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
              IconButton(
                icon: const Icon(Icons.compare_arrows),
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
          : const MessageView(
              icon: Icons.search_off,
              message: 'No apartments available right now.',
            );
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
            onTap: () => context.go(AppRoutes.apartmentDetail(apartment.id)),
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
