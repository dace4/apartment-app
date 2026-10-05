import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_routes.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/message_view.dart';
import '../data/apartment_repository.dart';
import '../models/apartment.dart';
import '../utils/apartment_formatters.dart';
import '../widgets/apartment_image.dart';

class ApartmentDetailPage extends StatefulWidget {
  const ApartmentDetailPage({
    super.key,
    required this.apartmentId,
    this.repository = const ApartmentRepository(),
  });

  final String apartmentId;
  final ApartmentRepository repository;

  @override
  State<ApartmentDetailPage> createState() => _ApartmentDetailPageState();
}

class _ApartmentDetailPageState extends State<ApartmentDetailPage> {
  late Future<Apartment?> _apartment;

  @override
  void initState() {
    super.initState();
    _apartment = widget.repository.fetchApartment(widget.apartmentId);
  }

  void _reload() {
    setState(() {
      _apartment = widget.repository.fetchApartment(widget.apartmentId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Apartment details')),
      body: FutureBuilder<Apartment?>(
        future: _apartment,
        builder: (context, snapshot) {
          // 1. Loading
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Error
          if (snapshot.hasError) {
            return MessageView(
              icon: Icons.cloud_off,
              message: 'Could not load this apartment.',
              actionLabel: 'Retry',
              onAction: _reload,
            );
          }

          // 3. Not found
          final apartment = snapshot.data;
          if (apartment == null) {
            return MessageView(
              icon: Icons.search_off,
              message:
                  'This apartment does not exist or is no longer '
                  'available.',
              actionLabel: 'Back to the list',
              onAction: () => context.go(AppRoutes.apartments),
            );
          }

          // 4. Data
          return _ApartmentDetails(apartment: apartment);
        },
      ),
    );
  }
}

/// Content of the page once the apartment is loaded.
class _ApartmentDetails extends StatelessWidget {
  const _ApartmentDetails({required this.apartment});

  final Apartment apartment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isForRent = apartment.listingType == ListingType.rent;

    return ListView(
      children: [
        ApartmentImage(imageUrl: apartment.imageUrl),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                formatApartmentPrice(apartment),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(apartment.title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.place_outlined, size: 18),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text('${apartment.address}, ${apartment.city}'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: const Icon(Icons.sell_outlined),
                    label: Text(isForRent ? 'For rent' : 'For sale'),
                  ),
                  Chip(
                    avatar: const Icon(Icons.bed_outlined),
                    label: Text(formatRooms(apartment.rooms)),
                  ),
                  Chip(
                    avatar: const Icon(Icons.square_foot),
                    label: Text('${apartment.surface} m²'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Description', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(apartment.description, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go(AppRoutes.apply(apartment.id)),
                icon: const Icon(Icons.send),
                label: const Text('Apply'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    context.go(AppRoutes.contactAdvertiser(apartment.id)),
                icon: const Icon(Icons.mail_outline),
                label: const Text('Contact advertiser'),
              ),
              if (!isForRent) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => context.go(AppRoutes.mortgage),
                  icon: const Icon(Icons.calculate_outlined),
                  label: const Text('Mortgage calculator'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
