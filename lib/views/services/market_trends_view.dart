import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/app_routes.dart';
import '../../utils/formatters.dart';
import '../../view_models/market_trends_view_model.dart';

class MarketTrendsView extends StatefulWidget {
  const MarketTrendsView({super.key, this.viewModel});
  final MarketTrendsViewModel? viewModel;

  @override
  State<MarketTrendsView> createState() => _MarketTrendsViewState();
}

class _MarketTrendsViewState extends State<MarketTrendsView> {
  late final viewModel = widget.viewModel ?? MarketTrendsViewModel();

  @override
  void initState() {
    super.initState();
    viewModel.listenToApartments();
  }

  @override
  void dispose() {
    if (widget.viewModel == null) viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Market trends')),
    body: ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        if (viewModel.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (viewModel.errorMessage != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(viewModel.errorMessage!),
                  TextButton(
                    onPressed: viewModel.listenToApartments,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Current sale listings',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Based on available and reserved apartments for sale in this app. These are asking prices, not completed sales.',
            ),
            const SizedBox(height: 8),
            const Text(
              'Price history is not recorded, so changes over time are unavailable.',
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              key: ValueKey(viewModel.selectedCity),
              initialValue: viewModel.selectedCity ?? '',
              decoration: const InputDecoration(
                labelText: 'City',
                border: OutlineInputBorder(),
              ),
              isExpanded: true,
              items: [
                const DropdownMenuItem(value: '', child: Text('All cities')),
                for (final city in viewModel.cities)
                  DropdownMenuItem(value: city, child: Text(city)),
              ],
              onChanged: (city) =>
                  viewModel.selectCity(city == '' ? null : city),
            ),
            const SizedBox(height: 24),
            if (viewModel.apartments.isEmpty)
              const Text('No sale listings with valid price and surface data.')
            else ...[
              Text('Listings included: ${viewModel.listingCount}'),
              const SizedBox(height: 12),
              Text(
                'Average asking price: ${formatChf(viewModel.averagePrice!)}',
              ),
              const SizedBox(height: 12),
              Text(
                'Average price per m²: ${formatChf(viewModel.averagePricePerSquareMetre!)} / m²',
              ),
              const SizedBox(height: 12),
              Text(
                'Asking price range: ${formatChf(viewModel.minimumPrice!)} – ${formatChf(viewModel.maximumPrice!)}',
              ),
              const SizedBox(height: 8),
              const Text('Each apartment has equal weight in the averages.'),
              const SizedBox(height: 24),
              Text(
                'Apartments behind these figures',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final apartment in viewModel.apartments) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(apartment.title),
                  subtitle: Text(
                    '${apartment.city} · ${formatChf(apartment.price)} · ${apartment.surface} m²',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      context.push(AppRoutes.apartmentDetail(apartment.id)),
                ),
                const Divider(height: 1),
              ],
            ],
          ],
        );
      },
    ),
  );
}
