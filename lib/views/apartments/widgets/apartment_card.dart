import 'package:flutter/material.dart';

import '../../../utils/formatters.dart';
import '../../../models/apartment.dart';
import '../../../view_models/favourites_view_model.dart';

import 'apartment_image.dart';
import 'availability_badge.dart';

//Summury of an apartment : photo, price, title, location and size
class ApartmentCard extends StatelessWidget {
  const ApartmentCard({
    super.key,
    required this.apartment,
    this.onTap,
    this.isSelectedForCompare = false,
    this.onCompare,
    this.favouritesViewModel,
  });

  final Apartment apartment;

  //Called when the cared is tapped, the card itself don't navigate so we can reused on any page
  final VoidCallback? onTap;
  final FavouritesViewModel? favouritesViewModel;

  /// US 13: the Compare chip is shown only when [onCompare] is given.
  final bool isSelectedForCompare;
  final VoidCallback? onCompare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final price = formatApartmentPrice(apartment);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ApartmentImage(imageUrl: apartment.imageUrl),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AvailabilityBadge(apartment: apartment),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          price,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (favouritesViewModel?.canUseFavourites == true)
                        IconButton(
                          tooltip: favouritesViewModel!.isFavorite(apartment.id)
                              ? 'Remove from favourites'
                              : 'Save to favourites',
                          icon: Icon(
                            favouritesViewModel!.isFavorite(apartment.id)
                                ? Icons.favorite
                                : Icons.favorite_border,
                          ),
                          onPressed: () =>
                              favouritesViewModel!.toggleFavorite(apartment),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    apartment.title,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.place_outlined, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${apartment.address}, ${apartment.city}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatRooms(apartment.rooms)} · ${apartment.surface} m²',
                  ),
                  if (onCompare != null) ...[
                    const SizedBox(height: 8),
                    FilterChip(
                      avatar: isSelectedForCompare
                          ? null
                          : const Icon(Icons.compare_arrows, size: 18),
                      label: const Text('Compare'),
                      selected: isSelectedForCompare,
                      onSelected: (_) => onCompare!(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
