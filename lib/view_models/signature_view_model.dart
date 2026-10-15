import 'package:flutter/foundation.dart';

import '../models/signature_drawing.dart';
import '../models/signature_point.dart';
import '../models/user_signature.dart';
import '../services/signature_service.dart';
import '../services/document_exception.dart';

/// US-11: draft drawing state; replacing never changes the signature ID.
class SignatureViewModel extends ChangeNotifier {
  SignatureViewModel({SignatureService? service})
    : service = service ?? SignatureService();
  final SignatureService service;
  UserSignature? savedSignature;
  final List<List<SignaturePoint>> _strokes = [];
  bool isLoading = false;
  bool isSaving = false;
  bool hasChanges = false;
  bool saved = false;
  String? errorMessage;
  String? actionError;
  bool _disposed = false;
  SignatureDrawing get drawing => SignatureDrawing(_strokes);
  bool get canSave => !isLoading && !isSaving && hasChanges && drawing.hasInk;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (isSaving) return;
    isLoading = true;
    errorMessage = null;
    _notify();
    try {
      final signature = await service.getMySignature();
      if (_disposed) return;
      savedSignature = signature;
      _strokes
        ..clear()
        ..addAll(signature?.drawing.strokes.map((s) => s.toList()) ?? []);
      hasChanges = false;
    } catch (error) {
      errorMessage = error is DocumentException
          ? error.message
          : 'Could not load your signature. Retry.';
    } finally {
      isLoading = false;
      _notify();
    }
  }

  void startStroke(SignaturePoint point) {
    if (isSaving || isLoading || !point.isValid) return;
    if (drawing.pointCount >= SignatureDrawing.maxPoints) {
      actionError = 'Clear the drawing and use a simpler signature.';
    } else {
      _strokes.add([point]);
      hasChanges = true;
      saved = false;
    }
    _notify();
  }

  void addPoint(SignaturePoint point) {
    if (isSaving || isLoading || _strokes.isEmpty || !point.isValid) return;
    if (drawing.pointCount < SignatureDrawing.maxPoints) {
      _strokes.last.add(point);
      hasChanges = true;
      saved = false;
    }
    _notify();
  }

  void clear() {
    if (isSaving || isLoading) return;
    _strokes.clear();
    hasChanges = true;
    actionError = null;
    saved = false;
    _notify();
  }

  Future<void> save() async {
    if (!canSave) return;
    isSaving = true;
    actionError = null;
    saved = false;
    _notify();
    try {
      savedSignature = await service.save(drawing);
      hasChanges = false;
      saved = true;
    } catch (error) {
      actionError = error is DocumentException
          ? error.message
          : 'The save could not be confirmed. Check your connection and retry.';
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
