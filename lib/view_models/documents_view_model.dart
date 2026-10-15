import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/document_upload.dart';
import '../models/uploaded_document.dart';
import '../services/document_exception.dart';
import '../services/document_service.dart';
import '../services/file_picker_service.dart';

/// US-15: the library and per-file upload queue with explicit retries.
class DocumentsViewModel extends ChangeNotifier {
  DocumentsViewModel({DocumentService? service, FilePickerService? picker})
    : service = service ?? DocumentService(),
      picker = picker ?? FilePickerService();
  final DocumentService service;
  final FilePickerService picker;
  List<UploadedDocument> documents = [];
  final List<DocumentUpload> uploads = [];
  final Map<String, String> uploadErrors = {};
  final Set<String> savedIds = {};
  final Set<String> uploadingIds = {};
  bool isLoading = false;
  bool isPicking = false;
  String? errorMessage;
  String? actionError;
  bool _disposed = false;
  StreamSubscription<List<UploadedDocument>>? _subscription;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void listenToDocuments() {
    _subscription?.cancel();
    isLoading = true;
    errorMessage = null;
    _notify();
    try {
      _subscription = service.watchMyDocuments().listen(
        (data) {
          documents = data;
          isLoading = false;
          _notify();
        },
        onError: (Object error) {
          isLoading = false;
          errorMessage = _message(
            error,
            'Could not load your documents. Check your connection and retry.',
          );
          _notify();
        },
      );
    } catch (error) {
      isLoading = false;
      errorMessage = _message(error, 'Could not load your documents.');
      _notify();
    }
  }

  Future<void> pickAndUpload() async {
    if (isPicking || uploadingIds.isNotEmpty) return;
    isPicking = true;
    actionError = null;
    _notify();
    try {
      final selected = await picker.pickDocuments(service);
      if (_disposed) return;
      if (selected.length > DocumentUpload.maxSelection) {
        throw const DocumentException('Choose at most 10 files at a time.');
      }
      uploads.removeWhere((upload) => savedIds.contains(upload.id));
      uploads.addAll(selected);
      for (final upload in selected) {
        if (_disposed) break;
        await retryUpload(upload);
      }
    } catch (error) {
      actionError = _message(error, 'Could not select files. Try again.');
    } finally {
      isPicking = false;
      _notify();
    }
  }

  Future<void> retryUpload(DocumentUpload upload) async {
    if (uploadingIds.contains(upload.id) || savedIds.contains(upload.id)) {
      return;
    }
    uploadingIds.add(upload.id);
    uploadErrors.remove(upload.id);
    _notify();
    try {
      await service.upload(upload);
      savedIds.add(upload.id);
    } catch (error) {
      uploadErrors[upload.id] = _message(
        error,
        'Upload could not be confirmed. Check your connection and retry.',
      );
    } finally {
      uploadingIds.remove(upload.id);
      _notify();
    }
  }

  void dismissUpload(DocumentUpload upload) {
    if (uploadingIds.contains(upload.id)) return;
    uploads.remove(upload);
    uploadErrors.remove(upload.id);
    _notify();
  }

  String uploadLabel(DocumentUpload upload) => savedIds.contains(upload.id)
      ? 'Uploaded'
      : uploadingIds.contains(upload.id)
      ? 'Uploading…'
      : uploadErrors[upload.id] ?? 'Waiting';
  String _message(Object error, String fallback) =>
      error is DocumentException ? error.message : fallback;
  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
