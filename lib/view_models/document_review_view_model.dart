import 'package:flutter/foundation.dart';

import '../models/uploaded_document.dart';
import '../services/document_service.dart';
import '../services/document_exception.dart';

/// US-15: the saved file preview and removal state for one screen.
class DocumentReviewViewModel extends ChangeNotifier {
  DocumentReviewViewModel({DocumentService? service})
    : service = service ?? DocumentService();
  final DocumentService service;
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
    final generation = ++_generation;
    isLoading = true;
    errorMessage = null;
    actionError = null;
    _notify();
    try {
      final loaded = await service.getDocument(id);
      if (!_disposed && generation == _generation) document = loaded;
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

  Future<bool> delete() async {
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
