import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/apartment.dart';
import '../../router/app_routes.dart';
import '../../utils/formatters.dart';
import '../../view_models/compare_view_model.dart';
import '../shared/widgets/message_view.dart';
import 'widgets/apartment_image.dart';

/// US 13: shows two apartments side by side, highlighting the better value
/// on each line.
class CompareView extends StatelessWidget {
  const CompareView({super.key, required this.viewModel});

  /// Shared with the apartment list and the apartment details.
  final CompareViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compare apartments')),
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          // 1. Not enough apartments selected
          if (!viewModel.canCompare) {
            return MessageView(
              icon: Icons.compare_arrows,
              message:
                  'Select two apartments to compare '
                  '(${viewModel.selected.length}/'
                  '${CompareViewModel.maxApartments} selected).',
              actionLabel: 'Browse apartments',
              onAction: () => context.go(AppRoutes.apartments),
            );
          }

          // 2. Comparison
          final left = viewModel.selected[0];
          final right = viewModel.selected[1];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(flex: 2),
                  Expanded(
                    flex: 3,
                    child: _Header(apartment: left, viewModel: viewModel),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: _Header(apartment: right, viewModel: viewModel),
                  ),
                ],
              ),
              if (viewModel.mixesRentAndSale) ...[
                const SizedBox(height: 16),
                const _Warning(
                  'One price is a monthly rent and the other a sale price: '
                  'they cannot be compared directly.',
                ),
              ],
              const SizedBox(height: 16),
              _CompareRow(
                label: 'Price',
                left: formatApartmentPrice(left),
                right: formatApartmentPrice(right),
                highlightLeft: viewModel.cheaperId == left.id,
                highlightRight: viewModel.cheaperId == right.id,
              ),
              _CompareRow(
                label: 'Price per m²',
                left: formatChf(left.pricePerSquareMetre),
                right: formatChf(right.pricePerSquareMetre),
                highlightLeft: viewModel.cheaperPerSquareMetreId == left.id,
                highlightRight: viewModel.cheaperPerSquareMetreId == right.id,
              ),
              _CompareRow(
                label: 'Surface',
                left: '${left.surface} m²',
                right: '${right.surface} m²',
                highlightLeft: viewModel.biggerId == left.id,
                highlightRight: viewModel.biggerId == right.id,
              ),
              _CompareRow(
                label: 'Rooms',
                left: formatRooms(left.rooms),
                right: formatRooms(right.rooms),
                highlightLeft: viewModel.moreRoomsId == left.id,
                highlightRight: viewModel.moreRoomsId == right.id,
              ),
              _CompareRow(label: 'City', left: left.city, right: right.city),
              _CompareRow(
                label: 'Type',
                left: _typeLabel(left),
                right: _typeLabel(right),
              ),
              _CompareRow(
                label: 'Availability',
                left: left.availability.label,
                right: right.availability.label,
              ),
              const SizedBox(height: 16),
              Text('Amenities', style: Theme.of(context).textTheme.titleMedium),
              for (final amenity in Amenity.values)
                _CompareRow(
                  label: amenity.label,
                  left: left.amenities.contains(amenity) ? '✓' : '—',
                  right: right.amenities.contains(amenity) ? '✓' : '—',
                ),
            ],
          );
        },
      ),
    );
  }

  static String _typeLabel(Apartment apartment) =>
      switch (apartment.listingType) {
        ListingType.rent => 'For rent',
        ListingType.sale => 'For sale',
      };
}

/// Photo, title and remove button above one column.
class _Header extends StatelessWidget {
  const _Header({required this.apartment, required this.viewModel});

  final Apartment apartment;
  final CompareViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(AppRoutes.apartmentDetail(apartment.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ApartmentImage(imageUrl: apartment.imageUrl),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                apartment.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            TextButton.icon(
              onPressed: () => viewModel.remove(apartment),
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Remove'),
            ),
          ],
        ),
      ),
    );
  }
}

/// One line of the comparison: a label and the value of each apartment.
/// The better value is shown in bold and in the primary colour.
class _CompareRow extends StatelessWidget {
  const _CompareRow({
    required this.label,
    required this.left,
    required this.right,
    this.highlightLeft = false,
    this.highlightRight = false,
  });

  final String label;
  final String left;
  final String right;
  final bool highlightLeft;
  final bool highlightRight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlight = TextStyle(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.bold,
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: theme.textTheme.labelLarge),
          ),
          Expanded(
            flex: 3,
            child: Text(left, style: highlightLeft ? highlight : null),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(right, style: highlightRight ? highlight : null),
          ),
        ],
      ),
    );
  }
}

/// Information banner shown above the comparison.
class _Warning extends StatelessWidget {
  const _Warning(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: colors.onTertiaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.onTertiaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
