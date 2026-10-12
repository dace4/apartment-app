import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../models/apartment.dart';
import '../../models/apartment_filter.dart';
import '../../view_models/apartments_view_model.dart';

/// US 5: lets the user choose the search criteria of the apartment list.
class FiltersView extends StatefulWidget {
  const FiltersView({super.key, required this.viewModel});

  /// Shared with the apartment list.
  final ApartmentsViewModel viewModel;

  @override
  State<FiltersView> createState() => _FiltersViewState();
}

class _FiltersViewState extends State<FiltersView> {
  // "Any" first, then the minimum number of rooms.
  static const _roomOptions = <double?>[null, 1, 2, 3, 4];

  final _formKey = GlobalKey<FormState>();

  // The form starts with the active filter. Nothing changes on the list
  // until Apply is pressed.
  late final _location = TextEditingController(text: _filter.location);
  late final _minPrice = TextEditingController(text: _toText(_filter.minPrice));
  late final _maxPrice = TextEditingController(text: _toText(_filter.maxPrice));
  late final _minSurface = TextEditingController(
    text: _toText(_filter.minSurface),
  );
  late ListingType? _listingType = _filter.listingType;
  late double? _minRooms = _filter.minRooms;
  late final Set<Amenity> _amenities = {..._filter.amenities};

  ApartmentFilter get _filter => widget.viewModel.filter;

  String _toText(int? value) => value?.toString() ?? '';

  @override
  void dispose() {
    _location.dispose();
    _minPrice.dispose();
    _maxPrice.dispose();
    _minSurface.dispose();
    super.dispose();
  }

  void _apply() {
    if (!_formKey.currentState!.validate()) return;

    widget.viewModel.applyFilter(
      ApartmentFilter(
        location: _location.text.trim(),
        listingType: _listingType,
        // An empty field gives null: no constraint.
        minPrice: int.tryParse(_minPrice.text),
        maxPrice: int.tryParse(_maxPrice.text),
        minRooms: _minRooms,
        minSurface: int.tryParse(_minSurface.text),
        amenities: _amenities,
      ),
    );
    context.pop();
  }

  void _reset() {
    _location.clear();
    _minPrice.clear();
    _maxPrice.clear();
    _minSurface.clear();
    setState(() {
      _listingType = null;
      _minRooms = null;
      _amenities.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Rents are monthly, sale prices are totals.
    final priceUnit = _listingType == ListingType.rent ? 'CHF / month' : 'CHF';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Filters'),
        actions: [TextButton(onPressed: _reset, child: const Text('Reset'))],
      ),
      // Outside the scrolling form, so Apply is always visible.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _apply,
            child: const Text('Apply filters'),
          ),
        ),
      ),
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
                  for (final type in [null, ...ListingType.values])
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
                      validator: (value) => widget.viewModel.validateMaxPrice(
                        _minPrice.text,
                        value,
                      ),
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
