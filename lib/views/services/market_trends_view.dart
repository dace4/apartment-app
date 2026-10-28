import 'package:flutter/material.dart';

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
    viewModel.fetchPrices();
  }

  @override
  void dispose() {
    if (widget.viewModel == null) viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Market trends')),
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          if (viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (viewModel.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(viewModel.errorMessage!),
                  TextButton(
                    onPressed: viewModel.fetchPrices,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Illustrative data',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sample apartment sale prices per m². These figures are fictional, not live market data or a property valuation.',
              ),
              const SizedBox(height: 24),
              if (viewModel.cities.isNotEmpty)
                DropdownButtonFormField<String>(
                  key: ValueKey(viewModel.selectedCity),
                  initialValue: viewModel.selectedCity,
                  decoration: const InputDecoration(
                    labelText: 'City',
                    border: OutlineInputBorder(),
                  ),
                  isExpanded: true,
                  items: [
                    for (final city in viewModel.cities)
                      DropdownMenuItem(value: city, child: Text(city)),
                  ],
                  onChanged: viewModel.selectCity,
                ),
              const SizedBox(height: 24),
              if (viewModel.prices.isEmpty)
                const Text('No market trends available.')
              else ...[
                Text(
                  viewModel.periodLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  'Latest sample price: ${formatChf(viewModel.latestPrice!)} / m²',
                ),
                const SizedBox(height: 8),
                Text(viewModel.changeLabel),
                const SizedBox(height: 24),
                const Text(
                  'Monthly sample prices',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                for (final price in viewModel.prices) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 24,
                      runSpacing: 4,
                      children: [
                        Text(price.monthLabel),
                        Text('${formatChf(price.pricePerSquareMetre)} / m²'),
                      ],
                    ),
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
}
