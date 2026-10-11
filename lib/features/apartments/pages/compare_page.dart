import 'package:flutter/material.dart';

import '../../../shared/utils/formatters.dart';
import '../../comparison/view_models/comparison_view_model.dart';
import '../models/apartment.dart';
import '../utils/apartment_formatters.dart';

enum _Side { first, second }

_Side? _lowerSide(int? first, int? second) {
  if (first == null || second == null || first == second) return null;
  return first < second ? _Side.first : _Side.second;
}

//US13: show 2 selected apa side by side
class ComparePage extends StatelessWidget {
  const ComparePage({super.key, required this.comparison});

  final ComparisonViewModel comparison;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compare apartments')),
      body: ListenableBuilder(
        listenable: comparison,
        builder: (context, _) {
          if (!comparison.canCompare) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Select 2 apartments of same type to compare them',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final first = comparison.selected[0];
          final second = comparison.selected[1];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _CompareRow(
                label: '',
                first: first.title,
                second: second.title,
                isHeader: true,
              ),
              const Divider(),

              _CompareRow(
                label: 'Price',
                first: formatApartmentPrice(first),
                second: formatApartmentPrice(second),
                best: _lowerSide(first.price, second.price),
              ),

              _CompareRow(
                label: 'Price /m2',
                first: _formatPricePerM2(first),
                second: _formatPricePerM2(second),
                best: _lowerSide(
                  pricePerSquareMeter(first),
                  pricePerSquareMeter(second),
                ),
              ),
              _CompareRow(
                label: 'Surface',
                first: '${first.surface} m2',
                second: '${second.surface} m2',
              ),
              _CompareRow(
                label: 'Rooms',
                first: formatRooms(first.rooms),
                second: formatRooms(second.rooms),
              ),
              _CompareRow(
                label: 'City',
                first: first.city,
                second: second.city,
              ),
              _CompareRow(
                label: 'Availability',
                first: first.availability.label,
                second: second.availability.label,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.clear),
                label: const Text('Clear comparison'),
                onPressed: comparison.clear,
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatPricePerM2(Apartment apartment) {
    final value = pricePerSquareMeter(apartment);
    return value == null ? '-' : '${formatChf(value)} /m2';
  }
}

class _CompareRow extends StatelessWidget {
  const _CompareRow({
    required this.label,
    required this.first,
    required this.second,
    this.best,
    this.isHeader = false,
  });

  final String label;
  final String first;
  final String second;
  final _Side? best;
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 96, child: Text(label)),
          Expanded(child: _value(context, first, best == _Side.first)),
          const SizedBox(width: 8),
          Expanded(child: _value(context, second, best == _Side.second)),
        ],
      ),
    );
  }

  Widget _value(BuildContext context, String text, bool isBest) {
    final theme = Theme.of(context);
    final style = isHeader
        ? theme.textTheme.titleSmall
        : isBest
        ? theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          )
        : theme.textTheme.bodyMedium;
    return Text(isBest ? '$text ✓' : text, style: style);
  }
}
