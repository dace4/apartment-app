import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/apartment.dart';
import '../models/apartment_filter.dart';

/// US 5: lets the user choose the search criteria of the apartment list.
class FiltersPage extends StatefulWidget {
  const FiltersPage({super.key, this.initialFilter = const ApartmentFilter()});

  /// Criteria already active on the list, shown pre-filled.
  final ApartmentFilter initialFilter;

  @override
  State<FiltersPage> createState() => _FiltersPageState();
}

class _FiltersPageState extends State<FiltersPage> {
  // "Any" first, then the minimum number of rooms.
  static const _roomOptions = <double?>[null, 1, 2, 3, 4];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _location;
  late final TextEditingController _minPrice;
  late final TextEditingController _maxPrice;
  late final TextEditingController _minSurface;
  late ListingType? _listingType;
  late double? _minRooms;
  late Set<Amenity> _amenities;

  @override
  void initState() {
    super.initState();
    final filter = widget.initialFilter;
    _location = TextEditingController(text: filter.location);
    _minPrice = TextEditingController(text: filter.minPrice?.toString() ?? '');
    _maxPrice = TextEditingController(text: filter.maxPrice?.toString() ?? '');
    _minSurface = TextEditingController(
      text: filter.minSurface?.toString() ?? '',
    );
    _listingType = filter.listingType;
    _minRooms = filter.minRooms;
    // A copy, so ticking a chip here does not change the list's filter.
    _amenities = {...filter.amenities};
  }

  @override
  void dispose() {
    _location.dispose();
    _minPrice.dispose();
    _maxPrice.dispose();
    _minSurface.dispose();
    super.dispose();
  }

  String? _validateMaxPrice(String? value) {
    final min = int.tryParse(_minPrice.text);
    final max = int.tryParse(value ?? '');
    if (min != null && max != null && max < min) {
      return 'Must be at least the minimum.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Rents are monthly, sale prices are totals.
    final priceUnit = _listingType == ListingType.rent ? 'CHF / month' : 'CHF';

    return Scaffold(
      appBar: AppBar(title: const Text('Filters')),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Section(
              title: 'Location',
              child: TextFormField(
                controller: _location,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  hintText: 'City or postcode, e.g. Sion or 1950',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            _Section(
              title: 'Rent or buy',
              child: Wrap(
                spacing: 8,
                children: [
                  for (final type in <ListingType?>[
                    null,
                    ...ListingType.values,
                  ])
                    ChoiceChip(
                      label: Text(switch (type) {
                        null => 'Any',
                        ListingType.rent => 'Rent',
                        ListingType.sale => 'Buy',
                      }),
                      selected: _listingType == type,
                      onSelected: (_) => setState(() => _listingType = type),
                    ),
                ],
              ),
            ),
            _Section(
              title: 'Price',
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _NumberField(
                      controller: _minPrice,
                      label: 'Min ($priceUnit)',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _NumberField(
                      controller: _maxPrice,
                      label: 'Max ($priceUnit)',
                      validator: _validateMaxPrice,
                    ),
                  ),
                ],
              ),
            ),
            _Section(
              title: 'Rooms',
              child: Wrap(
                spacing: 8,
                children: [
                  for (final rooms in _roomOptions)
                    ChoiceChip(
                      label: Text(rooms == null ? 'Any' : '${rooms.toInt()}+'),
                      selected: _minRooms == rooms,
                      onSelected: (_) => setState(() => _minRooms = rooms),
                    ),
                ],
              ),
            ),
            _Section(
              title: 'Surface',
              child: _NumberField(
                controller: _minSurface,
                label: 'Min surface (m²)',
              ),
            ),
            _Section(
              title: 'Amenities',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final amenity in Amenity.values)
                    FilterChip(
                      label: Text(amenity.label),
                      selected: _amenities.contains(amenity),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _amenities.add(amenity);
                        } else {
                          _amenities.remove(amenity);
                        }
                      }),
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

/// A titled block of the filters form.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// Text field that only accepts a whole positive number.
class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        // Up to 999'999'999, so the value always fits in an int.
        LengthLimitingTextInputFormatter(9),
      ],
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
