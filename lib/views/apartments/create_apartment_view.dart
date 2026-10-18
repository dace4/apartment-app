import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/apartment.dart';
import '../../router/app_routes.dart';
import '../../view_models/auth_view_model.dart';
import '../../view_models/create_apartment_view_model.dart';
import 'widgets/apartment_image.dart';

/// US-24: native form; validation and persistence belong to the ViewModel.
class CreateApartmentView extends StatefulWidget {
  const CreateApartmentView({
    super.key,
    required this.authViewModel,
    this.viewModel,
  });
  final AuthViewModel authViewModel;
  final CreateApartmentViewModel? viewModel;
  @override
  State<CreateApartmentView> createState() => _CreateApartmentViewState();
}

class _CreateApartmentViewState extends State<CreateApartmentView> {
  late final vm = widget.viewModel ?? CreateApartmentViewModel();
  final _title = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _price = TextEditingController();
  final _rooms = TextEditingController();
  final _surface = TextEditingController();
  final _description = TextEditingController();
  ListingType _type = ListingType.rent;
  final _amenities = <Amenity>{};
  @override
  void dispose() {
    if (widget.viewModel == null) vm.dispose();
    for (final c in [
      _title,
      _address,
      _city,
      _price,
      _rooms,
      _surface,
      _description,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _publish() async {
    final saved = await vm.publish(
      Apartment(
        id: '',
        title: _title.text.trim(),
        address: _address.text.trim(),
        city: _city.text.trim(),
        listingType: _type,
        price: int.tryParse(_price.text) ?? 0,
        rooms: double.tryParse(_rooms.text) ?? 0,
        surface: int.tryParse(_surface.text) ?? 0,
        imageUrl: vm.photos.isEmpty ? '' : vm.photos.first,
        imageUrls: vm.photos,
        description: _description.text.trim(),
        amenities: {..._amenities},
        availability: ApartmentAvailability.available,
      ),
    );
    if (saved && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Apartment published.')));
      context.go(AppRoutes.apartmentDetail(vm.publishedId!));
    }
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int? maxLength,
    TextInputType? keyboard,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      controller: controller,
      maxLength: maxLength,
      keyboardType: keyboard,
      maxLines: lines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([vm, widget.authViewModel]),
    builder: (context, _) {
      final allowed = widget.authViewModel.canAccess(AppRoutes.createApartment);
      final busy = vm.isSaving || vm.isPicking;
      return PopScope(
        canPop: !busy,
        child: Scaffold(
          appBar: AppBar(title: const Text('Add apartment')),
          body: !allowed
              ? const Center(
                  child: Text('A verified homeowner account is required.'),
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Publish your apartment',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'All fields are required. Your listing will be available to verified users as soon as you publish.',
                          ),
                          const SizedBox(height: 24),
                          AbsorbPointer(
                            absorbing: busy,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _field('Title', _title, maxLength: 200),
                                _field('Address', _address, maxLength: 200),
                                _field('City', _city, maxLength: 100),
                                DropdownButtonFormField<ListingType>(
                                  initialValue: _type,
                                  decoration: const InputDecoration(
                                    labelText: 'Listing type',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: ListingType.rent,
                                      child: Text('For rent'),
                                    ),
                                    DropdownMenuItem(
                                      value: ListingType.sale,
                                      child: Text('For sale'),
                                    ),
                                  ],
                                  onChanged: (value) =>
                                      setState(() => _type = value!),
                                ),
                                const SizedBox(height: 16),
                                _field(
                                  _type == ListingType.rent
                                      ? 'Monthly rent (CHF)'
                                      : 'Sale price (CHF)',
                                  _price,
                                  keyboard: TextInputType.number,
                                ),
                                _field(
                                  'Rooms (for example 3.5)',
                                  _rooms,
                                  keyboard:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                ),
                                _field(
                                  'Surface (m²)',
                                  _surface,
                                  keyboard: TextInputType.number,
                                ),
                                _field(
                                  'Description',
                                  _description,
                                  maxLength: 5000,
                                  lines: 5,
                                ),
                                Text(
                                  'Amenities (optional)',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                Wrap(
                                  spacing: 8,
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
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Pictures (${vm.photos.length}/6)',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Add 3 to 6 different JPEG or PNG pictures, up to 10 MiB each. The first is the cover. Pictures are resized and compressed for publication.',
                          ),
                          const SizedBox(height: 12),
                          for (var i = 0; i < vm.photos.length; i++) ...[
                            ApartmentImage(imageUrl: vm.photos[i]),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: busy
                                    ? null
                                    : () => vm.removePhoto(i),
                                icon: const Icon(Icons.delete_outline),
                                label: Text('Remove picture ${i + 1}'),
                              ),
                            ),
                          ],
                          OutlinedButton.icon(
                            onPressed: busy || vm.photos.length >= 6
                                ? null
                                : vm.pickImages,
                            icon: const Icon(
                              Icons.add_photo_alternate_outlined,
                            ),
                            label: Text(
                              vm.isPicking
                                  ? 'Preparing pictures…'
                                  : 'Add pictures',
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (vm.actionError != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Semantics(
                                liveRegion: true,
                                child: Text(
                                  vm.actionError!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                            ),
                          FilledButton.icon(
                            onPressed: busy ? null : _publish,
                            icon: vm.isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.publish),
                            label: Text(
                              vm.isSaving ? 'Publishing…' : 'Publish apartment',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      );
    },
  );
}
