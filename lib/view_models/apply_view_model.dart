import 'package:flutter/foundation.dart';

import '../models/apartment.dart';
import '../models/rental_application.dart';
import '../services/apartment_service.dart';
import '../services/application_service.dart';
import '../services/document_service.dart';
import '../services/document_exception.dart';
import '../models/uploaded_document.dart';

/// US 16: the application form for one apartment.
class ApplyViewModel extends ChangeNotifier {
  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  ApplyViewModel({this._canAccess, this._canApplyImmediately});
  final bool Function()? _canApplyImmediately;
  final bool Function()? _canAccess;
  bool get hasAccess => !_disposed && _canAccess?.call() == true;
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
    if (!hasAccess) {
      errorMessage = 'Choose Buyer or Renter to use this feature.';
      notifyListeners();
      return;
    }
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
  /// US 10: [immediately] only marks the application as immediate (renters
  /// only); it never reserves the apartment.
  Future<bool> submit(
    ApplicationDetails details, {
    bool immediately = false,
  }) async {
    if (!hasAccess || (immediately && _canApplyImmediately?.call() != true)) {
      actionError = 'Choose Buyer or Renter to use this feature.';
      notifyListeners();
      return false;
    }
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
        type: immediately ? ApplicationType.immediate : ApplicationType.normal,
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

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
