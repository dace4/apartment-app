import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/visit.dart';
import '../services/visit_exception.dart';
import '../services/visit_service.dart';

/// US-20: the visitor's visits, with cancelling.
class MyVisitsViewModel extends ChangeNotifier {
  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  // Tests pass a fake service and a fixed clock.
  MyVisitsViewModel({VisitService? service, DateTime Function()? clock})
    : service = service ?? VisitService(),
      _clock = clock ?? DateTime.now;

  final VisitService service;
  final DateTime Function() _clock;
  StreamSubscription<List<Visit>>? _subscription;

  List<Visit> _visits = [];
  bool isLoading = false;
  String? errorMessage;

  /// ID of the visit being cancelled.
  String? cancellingId;
  String? actionError;

  bool get isEmpty => _visits.isEmpty;

  /// Booked visits that are not over, soonest first.
  List<Visit> get upcoming =>
      _visits.where((visit) => visit.isUpcoming(_clock())).toList();

  /// Past and cancelled visits, latest first.
  List<Visit> get past => _visits
      .where((visit) => !visit.isUpcoming(_clock()))
      .toList()
      .reversed
      .toList();

  bool canCancel(Visit visit) => visit.canCancel(_clock());

  void listenToVisits() {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    _subscription?.cancel();
    _subscription = service.watchMyVisits().listen(
      (visits) {
        _visits = visits;
        isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        errorMessage = 'Could not load your visits.';
        isLoading = false;
        notifyListeners();
      },
    );
  }

  /// Returns true when the visit was cancelled.
  Future<bool> cancel(Visit visit) async {
    if (!canCancel(visit)) {
      actionError = 'This visit has already started and cannot be cancelled.';
      notifyListeners();
      return false;
    }
    cancellingId = visit.id;
    actionError = null;
    notifyListeners();

    try {
      await service.cancel(visit);
      return true;
    } on VisitException catch (e) {
      actionError = e.message;
      return false;
    } catch (e) {
      actionError = 'Could not cancel the visit. Please try again.';
      return false;
    } finally {
      cancellingId = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
