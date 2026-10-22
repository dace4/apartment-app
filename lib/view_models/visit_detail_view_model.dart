import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/visit.dart';
import '../services/visit_service.dart';

/// US-20: one visit of the owner's apartment: who is coming and when. Opened
/// from the owner's "New visit" or "Visit cancelled" notification.
class VisitDetailViewModel extends ChangeNotifier {
  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  // Tests pass a fake service and a fixed clock.
  VisitDetailViewModel({VisitService? service, DateTime Function()? clock})
    : service = service ?? VisitService(),
      _clock = clock ?? DateTime.now;

  final VisitService service;
  final DateTime Function() _clock;
  StreamSubscription<Visit?>? _subscription;

  /// null once loaded means the visit does not exist.
  Visit? visit;
  bool isLoading = false;
  String? errorMessage;

  /// "Booked", "Cancelled", or "Done" once the visit has ended.
  String get statusLabel {
    final current = visit;
    if (current == null) return '';
    if (current.isCancelled) return current.status.label;
    return current.isUpcoming(_clock()) ? current.status.label : 'Done';
  }

  void listenToVisit(String id) {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    _subscription?.cancel();
    _subscription = service
        .watchVisit(id)
        .listen(
          (updated) {
            visit = updated;
            isLoading = false;
            notifyListeners();
          },
          onError: (e) {
            errorMessage = 'Could not load this visit.';
            isLoading = false;
            notifyListeners();
          },
        );
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
