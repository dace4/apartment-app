import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/signing_document.dart';
import '../services/document_exception.dart';
import '../services/document_service.dart';

/// US-11: the live list combines assignments with completed signing records.
class DocumentsViewModel extends ChangeNotifier {
  DocumentsViewModel({DocumentService? service})
    : service = service ?? DocumentService();
  final DocumentService service;
  List<SigningDocument> documents = [];
  Set<String> signedIds = {};
  bool isLoading = false;
  String? errorMessage;
  bool _documentsLoaded = false;
  bool _recordsLoaded = false;
  StreamSubscription<List<SigningDocument>>? _documentsSubscription;
  StreamSubscription<Set<String>>? _recordsSubscription;

  String statusLabel(SigningDocument document) =>
      signedIds.contains(document.id)
      ? 'Signed'
      : document.isReady && document.isValid
      ? 'Awaiting signature'
      : 'Unavailable';

  void listenToDocuments() {
    _documentsSubscription?.cancel();
    _recordsSubscription?.cancel();
    isLoading = true;
    errorMessage = null;
    _documentsLoaded = false;
    _recordsLoaded = false;
    documents = [];
    signedIds = {};
    notifyListeners();
    try {
      _documentsSubscription = service.watchMyDocuments().listen((data) {
        documents = data;
        _documentsLoaded = true;
        _loaded();
      }, onError: _failed);
      _recordsSubscription = service.watchMySignedIds().listen((data) {
        signedIds = data;
        _recordsLoaded = true;
        _loaded();
      }, onError: _failed);
    } catch (error) {
      _failed(error);
    }
  }

  void _loaded() {
    isLoading = !(_documentsLoaded && _recordsLoaded);
    notifyListeners();
  }

  void _failed(Object error) {
    isLoading = false;
    errorMessage = error is DocumentException
        ? error.message
        : 'Could not load your documents. Check your connection and retry.';
    notifyListeners();
  }

  @override
  void dispose() {
    _documentsSubscription?.cancel();
    _recordsSubscription?.cancel();
    super.dispose();
  }
}
