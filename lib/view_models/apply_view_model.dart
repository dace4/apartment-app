import 'package:flutter/foundation.dart';

import '../models/apartment.dart';
import '../models/rental_application.dart';
import '../services/apartment_service.dart';
import '../services/application_service.dart';
import '../services/document_service.dart';
import '../services/document_exception.dart';
import '../models/uploaded_document.dart';
import '../services/reservation_exceptions.dart';

/// US 16: the application form for one apartment.
class ApplyViewModel extends ChangeNotifier {
  final ApartmentService apartmentService = ApartmentService();
  final ApplicationService applicationService = ApplicationService();
  final DocumentService documentService = DocumentService();
  List<UploadedDocument> documents = [];
  final Set<String> selectedDocumentIds = {};
  String? attachmentError;
  String? _submissionId;

  /// null once loaded means the apartment does not exist.
  Apartment? apartment;
  bool isLoading = false;
  String? errorMessage;

  bool isSaving = false;
  String? actionError;

  Future<void> fetchApartment(String id) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      apartment = await apartmentService.getApartment(id);
      try {
        documents = await documentService.getMyDocuments();
        attachmentError = null;
      } catch (_) {
        attachmentError =
            'Could not load attachments. You can retry or apply without them.';
      }
    } catch (e) {
      errorMessage = 'Could not load the apartment.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Returns true when the application was submitted.
  Future<bool> submit(ApplicationDetails details) async {
    if (isSaving) return false;
    isSaving = true;
    actionError = null;
    notifyListeners();

    try {
      // Only one open application per apartment.
      final myApplications = await applicationService.getMyApplications();
      final alreadyApplied = myApplications.any(
        (application) =>
            application.apartmentId == apartment!.id &&
            application.status.isOpen &&
            application.id != _submissionId,
      );
      if (alreadyApplied) {
        actionError =
            'You already have an open application for this apartment.';
        return false;
      }

      _submissionId ??= applicationService.newSubmissionId();
      await applicationService.submit(
        apartment!,
        details,
        documentIds: selectedDocumentIds.toList(),
        submissionId: _submissionId,
      );
      return true;
    } catch (e) {
      actionError = e is DocumentException
          ? e.message
          : 'Could not confirm the application. Please retry.';
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  void selectDocument(String id, bool selected) {
    if (isSaving || !documents.any((doc) => doc.id == id)) return;
    if (selected && selectedDocumentIds.length >= 5) {
      actionError = 'Select at most five attachments.';
    } else {
      selected ? selectedDocumentIds.add(id) : selectedDocumentIds.remove(id);
      actionError = null;
    }
    notifyListeners();
  }

  /// Returns true once the application and apartment reservation commit.
  Future<bool> submitImmediately(ApplicationDetails details) async {
    final target = apartment;
    if (target == null || isSaving) return false; // also blocks double taps

    isSaving = true;
    actionError = null;
    notifyListeners();

    try {
      // An existing normal application can be promoted from its detail page.
      // Do not create a second open application for the same renter/listing.
      final myApplications = await applicationService.getMyApplications();
      final alreadyApplied = myApplications.any(
        (application) =>
            application.apartmentId == target.id && application.status.isOpen,
      );
      if (alreadyApplied) {
        actionError =
            'You already have an open application for this apartment. '
            'Open it to apply immediately.';
        return false;
      }

      await applicationService.submitImmediately(target, details);
      return true;
    } catch (error) {
      actionError = reservationErrorMessage(error);
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
