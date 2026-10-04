import 'package:flutter/material.dart';

import '../../../shared/utils/formatters.dart';
import '../models/apartment.dart';

//Summury of an apartment : photo, price, title, location and size
class ApartmentCard extends StatelessWidget {
  const ApartmentCard({super.key, required this.apartment, this.onTap});

  final Apartment apartment;

  //Called when the cared is tapped, the card itself don't navigate so we can reused on any page
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final price = switch (apartment.listingType) {
      ListingType.rent => '${formatChf(apartment.price)} / month',
      ListingType.sale => formatChf(apartment.price),
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ColoredBox(
                // Grey background shown while the image is loading.
                color: theme.colorScheme.surfaceContainerHighest,
                child: Image.network(
                  apartment.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Center(child: Icon(Icons.home_outlined, size: 48)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    price,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
