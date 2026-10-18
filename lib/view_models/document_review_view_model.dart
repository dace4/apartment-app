import 'package:flutter/foundation.dart';

import '../models/uploaded_document.dart';
import '../services/document_service.dart';
import '../services/document_exception.dart';
import '../services/signature_service.dart';

/// US-15: the saved file preview and removal state for one screen.
class DocumentReviewViewModel extends ChangeNotifier {
  DocumentReviewViewModel({
    this._canAccess,
    DocumentService? service,
    SignatureService? signatureService,
  }) : service = service ?? DocumentService(),
       signatureService = signatureService ?? SignatureService();
  final bool Function()? _canAccess;
  bool get hasAccess => !_disposed && _canAccess?.call() == true;
  final DocumentService service;
  final SignatureService signatureService;
  bool hasSignature = false;
  String? signatureError;
  bool get canBind =>
      hasAccess &&
      !isLoading &&
      !isSaving &&
      document != null &&
      !document!.isSigned &&
      hasSignature;
  UploadedDocument? document;
  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;
  String? actionError;
  bool _disposed = false;
  int _generation = 0;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load(String id) async {
    if (!hasAccess) {
      errorMessage = 'Choose Buyer or Renter to use this feature.';
      _notify();
      return;
    }
    final generation = ++_generation;
    isLoading = true;
    errorMessage = null;
    actionError = null;
    _notify();
    try {
      final loaded = await service.getDocument(id);
      if (!_disposed && generation == _generation) document = loaded;
      try {
        final signature = await signatureService.getMySignature();
        if (!_disposed && generation == _generation) {
          hasSignature = signature != null;
          signatureError = null;
        }
      } catch (_) {
        if (!_disposed && generation == _generation) {
          hasSignature = false;
          signatureError =
              'Could not load your signature. Reload the document to retry.';
        }
      }
    } catch (error) {
      if (generation == _generation) {
        errorMessage = error is DocumentException
            ? error.message
            : 'Could not load this document. Check your connection and retry.';
      }
    } finally {
      if (generation == _generation) {
        isLoading = false;
        _notify();
      }
    }
  }

  Future<void> bind() async {
    if (!hasAccess) {
      actionError = 'Choose Buyer or Renter to use this feature.';
      _notify();
      return;
    }
    if (!canBind) return;
    isSaving = true;
    actionError = null;
    _notify();
    try {
      document = await service.bindSignature(document!.id);
    } catch (error) {
      actionError = error is DocumentException ? error.message : 'The binding could not be confirmed. Check your connection and retry.';
    } finally {
      isSaving = false;
      _notify();
    }
  }

  Future<bool> delete() async {
    if (!hasAccess) {
      actionError = 'Choose Buyer or Renter to use this feature.';
      _notify();
      return false;
    }
    if (isSaving || document == null || !document!.canDelete) return false;
    isSaving = true;
    actionError = null;
    _notify();
    try {
      await service.delete(document!.id);
      return true;
    } catch (error) {
      actionError = error is DocumentException
          ? error.message
          : 'Could not remove this document. Retry.';
      return false;
    } finally {
      isSaving = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
