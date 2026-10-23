import 'package:flutter/foundation.dart';

import '../models/apartment.dart';
import '../services/apartment_service.dart';
import '../services/listing_exception.dart';
import '../services/listing_image_service.dart';
import '../utils/listing_validation.dart';

/// US-24: form validation and publication state for one screen.
class CreateApartmentViewModel extends ChangeNotifier {
  CreateApartmentViewModel({
    ApartmentService? service,
    ListingImageService? images,
  }) : service = service ?? ApartmentService(),
       images = images ?? ListingImageService();
  final ApartmentService service;
  final ListingImageService images;
  List<String> _photos = [];
  List<String> get photos => List.unmodifiable(_photos);
  bool isSaving = false;
  bool isPicking = false;
  String? actionError;
  String? publishedId;
  String? _draftId;
  bool _disposed = false;

  Future<void> pickImages() async {
    if (isPicking || isSaving || publishedId != null) return;
    isPicking = true;
    actionError = null;
    notifyListeners();
    try {
      final selected = await images.pickImages();
      if (_disposed) return;
      final combined = {..._photos, ...selected}.toList();
      if (combined.length > 6) {
        throw const ListingException(
          'Keep at most 6 pictures. Remove one first.',
        );
      }
      _photos = combined;
    } on ListingException catch (e) {
      actionError = e.message;
    } catch (_) {
      actionError = 'Could not read the pictures. Select them again.';
    } finally {
      isPicking = false;
      notifyListeners();
    }
  }

  void removePhoto(int index) {
    if (isSaving || isPicking || publishedId != null) return;
    _photos = [..._photos]..removeAt(index);
    notifyListeners();
  }

  Future<bool> publish(Apartment listing) async {
    if (isSaving || isPicking || publishedId != null) return false;
    actionError = validateListing(listing);
    if (actionError != null) {
      notifyListeners();
      return false;
    }
    isSaving = true;
    notifyListeners();
    try {
      // Reuse the ID on retry, so an uncertain response cannot duplicate a listing.
      _draftId ??= service.newApartmentId();
      await service.createApartment(_draftId!, listing);
      publishedId = _draftId;
      return true;
    } on ListingException catch (e) {
      actionError = e.message;
      return false;
    } catch (_) {
      actionError =
          'Could not publish the apartment. Your form is kept; try again.';
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
