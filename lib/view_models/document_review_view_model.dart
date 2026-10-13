import 'package:flutter/foundation.dart';

import '../models/signature_drawing.dart';
import '../models/signature_point.dart';
import '../models/signed_document.dart';
import '../models/signing_document.dart';
import '../services/document_exception.dart';
import '../services/document_service.dart';

/// US-11: review, consent, capture, and confirmed persistence for one screen.
class DocumentReviewViewModel extends ChangeNotifier {
  DocumentReviewViewModel({DocumentService? service})
    : service = service ?? DocumentService();
  final DocumentService service;
  SigningDocument? document;
  SignedDocument? signedRecord;
  bool isLoading = false;
  String? errorMessage;
  bool isSaving = false;
  String? actionError;
  bool reviewed = false;
  bool consented = false;
  String signerName = '';
  final List<List<SignaturePoint>> _strokes = [];
  bool _disposed = false;
  int _loadGeneration = 0;

  SignatureDrawing get signature => SignatureDrawing(_strokes);
  bool get canSign =>
      !isLoading &&
      !isSaving &&
      errorMessage == null &&
      document?.isReady == true &&
      document?.isValid == true &&
      signedRecord == null;
  bool get canSubmit =>
      canSign &&
      reviewed &&
      consented &&
      signerName.trim().isNotEmpty &&
      signerName.trim().length <= 100 &&
      signature.hasInk;
  String get statusLabel => signedRecord != null
      ? 'Signed'
      : document?.isReady == true
      ? 'Awaiting signature'
      : 'Unavailable';

  Future<void> load(String id) async {
    if (isSaving) return;
    final generation = ++_loadGeneration;
    isLoading = true;
    errorMessage = null;
    actionError = null;
    document = null;
    signedRecord = null;
    reviewed = false;
    consented = false;
    signerName = '';
    _strokes.clear();
    notifyListeners();
    try {
      final record = await service.getSignedRecord(id);
      final source = record?.document ?? await service.getDocument(id);
      if (_disposed || generation != _loadGeneration) return;
      signedRecord = record;
      document = source;
    } catch (error) {
      if (_disposed || generation != _loadGeneration) return;
      errorMessage = error is DocumentException
          ? error.message
          : 'Could not load this document. Check your connection and retry.';
    } finally {
      if (!_disposed && generation == _loadGeneration) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  void setReviewed(bool value) {
    if (!canSign) return;
    reviewed = value;
    if (!value) consented = false;
    notifyListeners();
  }

  void setConsented(bool value) {
    if (!canSign || !reviewed) return;
    consented = value;
    notifyListeners();
  }

  void setSignerName(String value) {
    if (!canSign) return;
    signerName = value;
    notifyListeners();
  }

  void startStroke(SignaturePoint point) {
    if (!canSign || !point.isValid) return;
    if (signature.pointCount >= SignatureDrawing.maxPoints) {
      actionError = 'The signature is too detailed. Clear it and draw a simpler signature.';
    } else {
      _strokes.add([point]);
    }
    notifyListeners();
  }

  void addPoint(SignaturePoint point) {
    if (!canSign || _strokes.isEmpty || !point.isValid) return;
    if (signature.pointCount >= SignatureDrawing.maxPoints) {
      actionError = 'The signature is too detailed. Clear it and draw a simpler signature.';
    } else {
      _strokes.last.add(point);
    }
    notifyListeners();
  }

  void clearSignature() {
    if (!canSign) return;
    _strokes.clear();
    consented = false;
    actionError = null;
    notifyListeners();
  }

  Future<bool> sign() async {
    if (isSaving || signedRecord != null) return false;
    if (!canSubmit) {
      actionError = 'Confirm your review, enter your name, draw your signature, and give consent.';
      notifyListeners();
      return false;
    }
    isSaving = true;
    actionError = null;
    notifyListeners();
    try {
      await service.sign(
        reviewedDocument: document!,
        signature: signature,
        signerName: signerName,
        consented: consented,
      );
      final record = await service.getSignedRecord(document!.id);
      if (_disposed) return false;
      if (record == null) {
        throw const DocumentException(
          'The save could not be confirmed. Check your connection and retry.',
        );
      }
      signedRecord = record;
      document = record.document;
      _strokes.clear();
      return true;
    } catch (error) {
      if (!_disposed) {
        actionError = error is DocumentException
            ? error.message
            : 'The save could not be confirmed. Check your connection and retry. '
                  'If it already saved, retrying will open the existing record.';
      }
      return false;
    } finally {
      if (!_disposed) {
        isSaving = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
