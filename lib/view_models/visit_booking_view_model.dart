import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/apartment.dart';
import '../models/visit.dart';
import '../services/apartment_service.dart';
import '../services/visit_exception.dart';
import '../services/visit_service.dart';
import '../utils/formatters.dart';
import '../utils/visit_schedule.dart';

/// What a time slot shows in the calendar.
enum SlotStatus {
  /// Green dot: can be booked.
  free('Free'),

  /// Red dot: another visitor booked it.
  taken('Taken'),

  /// The user's own visit.
  yours('Your visit');

  const SlotStatus(this.label);
  final String label;
}

/// One slot of the chosen day.
typedef DaySlot = ({DateTime start, DateTime end, SlotStatus status});

/// US-20: choose a day in the calendar and a free slot, then book a visit.
class VisitBookingViewModel extends ChangeNotifier {
  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  // Tests pass fakes and a fixed clock; the app uses Firebase and the time.
  VisitBookingViewModel({
    ApartmentService? apartmentService,
    VisitService? service,
    DateTime Function()? clock,
  }) : apartmentService = apartmentService ?? ApartmentService(),
       service = service ?? VisitService(),
       _clock = clock ?? DateTime.now;

  final ApartmentService apartmentService;
  final VisitService service;
  final DateTime Function() _clock;

  StreamSubscription<Set<DateTime>>? _slotsSubscription;
  StreamSubscription<List<Visit>>? _visitsSubscription;

  /// null once loaded means the apartment does not exist.
  Apartment? apartment;
  bool isLoading = false;
  String? errorMessage;

  Set<DateTime> _taken = {};
  List<Visit> _myVisits = [];
  bool _slotsLoaded = false;
  bool _visitsLoaded = false;

  DateTime? selectedDate;
  DateTime? selectedSlot;

  bool isSaving = false;
  String? actionError;

  /// Set once the visit is booked: the page then shows a confirmation.
  Visit? bookedVisit;

  Future<void> load(String apartmentId) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      apartment = await apartmentService.getApartment(apartmentId);
    } catch (e) {
      errorMessage = 'Could not load this apartment.';
      isLoading = false;
      notifyListeners();
      return;
    }
    if (apartment == null) {
      isLoading = false;
      notifyListeners();
      return;
    }
    selectedDate = VisitSchedule.firstSelectableDay(_clock());

    _slotsSubscription?.cancel();
    _slotsSubscription = service.watchTakenSlots(apartmentId).listen((taken) {
      _taken = taken;
      _slotsLoaded = true;
      // A slot taken meanwhile cannot stay selected.
      if (selectedSlot != null && _taken.contains(selectedSlot)) {
        selectedSlot = null;
      }
      _updateLoading();
    }, onError: (e) => _loadFailed());
    _visitsSubscription?.cancel();
    _visitsSubscription = service.watchMyVisits().listen((visits) {
      _myVisits = visits;
      _visitsLoaded = true;
      _updateLoading();
    }, onError: (e) => _loadFailed());
  }

  void _updateLoading() {
    isLoading = !(_slotsLoaded && _visitsLoaded);
    notifyListeners();
  }

  void _loadFailed() {
    errorMessage = 'Could not load the visit times.';
    isLoading = false;
    notifyListeners();
  }

  // Calendar limits (20.1: Monday to Friday, from tomorrow to 30 days ahead).
  DateTime get firstDate => VisitSchedule.firstDate(_clock());
  DateTime get lastDate => VisitSchedule.lastDate(_clock());
  bool isSelectableDay(DateTime day) =>
      VisitSchedule.isSelectableDay(day, _clock());

  /// The user's upcoming visit of this apartment, if any.
  Visit? get existingVisit {
    final now = _clock();
    for (final visit in _myVisits) {
      if (visit.apartmentId == apartment?.id && visit.isUpcoming(now)) {
        return visit;
      }
    }
    return null;
  }

  /// Why the user cannot book a visit of this apartment, or null if they can.
  String? get cannotBookReason {
    final listing = apartment;
    if (listing == null) return null;
    if (listing.ownerId == null) {
      return 'Visits cannot be booked for this apartment yet. Contact the '
          'advertiser instead.';
    }
    final userId = service.currentUserId;
    if (listing.ownerId == userId || listing.managerIds.contains(userId)) {
      return 'You own or manage this apartment, so you cannot book a visit.';
    }
    if (!listing.canApply) {
      return 'Only available apartments can be visited.';
    }
    final visit = existingVisit;
    if (visit != null) {
      return 'You already booked a visit on '
          '${formatTimeSlot(visit.slotStart, visit.slotEnd)}. Cancel it in '
          'My visits to choose another time.';
    }
    return null;
  }

  bool get canBook => apartment != null && cannotBookReason == null;

  /// The morning and afternoon slots of the chosen day.
  List<DaySlot> get slots {
    final date = selectedDate;
    if (date == null) return const [];
    return [
      for (final start in VisitSchedule.slotsFor(date))
        (
          start: start,
          end: start.add(Visit.slotLength),
          status: _status(start),
        ),
    ];
  }

  SlotStatus _status(DateTime start) {
    final mine = existingVisit;
    if (mine != null && mine.slotStart == start) return SlotStatus.yours;
    return _taken.contains(start) ? SlotStatus.taken : SlotStatus.free;
  }

  void selectDate(DateTime value) {
    selectedDate = VisitSchedule.dateOnly(value);
    selectedSlot = null;
    actionError = null;
    notifyListeners();
  }

  void selectSlot(DateTime value) {
    if (!canBook || _status(value) != SlotStatus.free) return;
    selectedSlot = value;
    actionError = null;
    notifyListeners();
  }

  /// Returns true when the visit was booked; [bookedVisit] is then set.
  Future<bool> book() async {
    final slot = selectedSlot;
    if (!canBook || slot == null) {
      actionError = 'Choose a free time slot.';
      notifyListeners();
      return false;
    }
    // The day may have become today since the page was opened.
    if (!VisitSchedule.isBookable(slot, _clock())) {
      actionError =
          'This time slot can no longer be booked. Choose another '
          'day.';
      selectedSlot = null;
      notifyListeners();
      return false;
    }

    isSaving = true;
    actionError = null;
    notifyListeners();

    try {
      bookedVisit = await service.book(apartment!, slot);
      return true;
    } on VisitException catch (e) {
      actionError = e.message;
      selectedSlot = null;
      return false;
    } catch (e) {
      actionError = 'Could not book the visit. Please try again.';
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _slotsSubscription?.cancel();
    _visitsSubscription?.cancel();
    super.dispose();
  }
}
