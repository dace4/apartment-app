import 'package:flutter/foundation.dart';

import '../models/apartment.dart';
import '../models/maintenance_request.dart';
import '../services/auth_service.dart';
import '../services/maintenance_service.dart';
import '../utils/maintenance_schedule.dart';

/// What a time slot shows in the booking flow.
enum SlotState {
  free,

  /// Another of the user's services already uses it.
  booked,

  /// The service being rescheduled is in this slot.
  current,

  /// Today or earlier, or more than 60 days away.
  unavailable,
}

/// US-17: book a new repair or maintenance service, or reschedule one.
/// US-17.1: only property managers, for the apartments they are assigned
/// to (Sprint 3 review).
class MaintenanceBookingViewModel extends ChangeNotifier {
  // Tests pass fakes and a fixed clock; the app uses Firebase and now().
  MaintenanceBookingViewModel({
    MaintenanceService? service,
    AuthService? authService,
    DateTime Function()? clock,
  }) : service = service ?? MaintenanceService(),
       authService = authService ?? AuthService(),
       _now = clock ?? DateTime.now;

  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  final MaintenanceService service;
  final AuthService authService;
  final DateTime Function() _now;

  /// The service being rescheduled, or null when booking a new one.
  MaintenanceRequest? existing;
  bool get isRescheduling => existing != null;

  /// The apartments to choose from (new booking only).
  List<Apartment> apartments = [];

  /// The user's scheduled services, to know which slots are taken.
  List<MaintenanceRequest> _scheduled = [];

  bool isLoading = false;
  String? errorMessage;

  bool isSaving = false;
  String? actionError;

  /// The ID of the booked or rescheduled service, for navigation.
  String? savedId;

  // Choices of the form.
  Apartment? apartment;
  MaintenanceCategory? category;
  Set<MaintenanceReminder> reminders = {MaintenanceReminder.oneDay};
  DateTime? date;
  DateTime? slot;

  /// Set after the first submit, so the reminder and slot errors only show
  /// once the user tried to book.
  bool _submitted = false;

  Future<void> load({String? rescheduleId}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      _scheduled = _onlyScheduled(await service.getMyRequests());
      if (rescheduleId == null) {
        apartments = await service.getManageableApartments()
          ..sort((a, b) => a.title.compareTo(b.title));
      } else {
        existing = await service.getRequest(rescheduleId);
        if (existing == null) {
          errorMessage = 'This maintenance service does not exist.';
        } else if (!existing!.canChange(_now())) {
          errorMessage = 'This service can no longer be rescheduled.';
        } else {
          reminders = {...existing!.reminders};
        }
      }
    } catch (e) {
      errorMessage = 'Could not load the booking form.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // Date picker limits (17.1 scheduling rules).
  DateTime get firstDate => MaintenanceSchedule.firstDate(_now());
  DateTime get lastDate => MaintenanceSchedule.lastDate(_now());
  DateTime get pickerInitialDate =>
      date ?? MaintenanceSchedule.firstSelectableDay(_now());
  bool isSelectableDay(DateTime day) =>
      MaintenanceSchedule.isSelectableDay(day, _now());

  /// The times that can be booked on the chosen date, for the time wheel.
  /// Booked, current and too-soon slots are left out.
  List<DateTime> get availableSlots => date == null
      ? const []
      : MaintenanceSchedule.slotsFor(date!)
            .where((slot) => slotState(slot) == SlotState.free)
            .toList();

  SlotState slotState(DateTime slot) {
    if (existing != null && slot == existing!.slotStart) {
      return SlotState.current;
    }
    if (!MaintenanceSchedule.isBookable(slot, _now())) {
      return SlotState.unavailable;
    }
    if (_isTaken(slot)) return SlotState.booked;
    return SlotState.free;
  }

  /// A manager cannot have two services in the same slot. The service
  /// being rescheduled does not block itself.
  bool _isTaken(DateTime slot) => _scheduled.any(
    (request) => request.id != existing?.id && request.slotStart == slot,
  );

  void selectApartment(Apartment? value) {
    apartment = value;
    notifyListeners();
  }

  void selectCategory(MaintenanceCategory? value) {
    category = value;
    notifyListeners();
  }

  void setReminder(MaintenanceReminder reminder, bool selected) {
    reminders = selected
        ? {...reminders, reminder}
        : reminders.where((item) => item != reminder).toSet();
    notifyListeners();
  }

  /// US-17.2: the time wheel always shows a time, so the first free time
  /// of the new date is selected (null when the day has none).
  /// Choosing the same date again keeps the chosen time.
  void selectDate(DateTime value) {
    final day = MaintenanceSchedule.dateOnly(value);
    if (day == date) return;
    date = day;
    slot = availableSlots.firstOrNull;
    notifyListeners();
  }

  void selectSlot(DateTime value) {
    if (slotState(value) != SlotState.free) return;
    slot = value;
    notifyListeners();
  }

  // Validators. Generic ones are in utils/validators.dart; these belong to
  // this screen only.
  String? validateApartment(Apartment? value) =>
      value == null ? 'Choose an apartment.' : null;

  String? validateCategory(MaintenanceCategory? value) =>
      value == null ? 'Choose a category.' : null;

  String? validateDescription(String? value) {
    final text = value?.trim() ?? '';
    if (text.length < 5) return 'Describe the problem (at least 5 characters).';
    if (text.length > 500) return 'Use at most 500 characters.';
    return null;
  }

  String? get reminderError =>
      _submitted && reminders.isEmpty ? 'Choose at least one reminder.' : null;

  String? get slotError =>
      _submitted && slot == null ? 'Choose a date and a time slot.' : null;

  /// Shows the reminder and slot errors.
  void markSubmitted() {
    _submitted = true;
    notifyListeners();
  }

  /// Returns true when the service was booked; [savedId] is then set.
  Future<bool> book(String description) => _save(
    () => service.book(
      apartment: apartment!,
      category: category!,
      description: description,
      slotStart: slot!,
      reminders: reminders,
    ),
  );

  /// Returns true when the service was moved; [savedId] is then set.
  Future<bool> reschedule() => _save(() async {
    await service.reschedule(existing!.id, slot!, reminders);
    return existing!.id;
  });

  Future<bool> _save(Future<String> Function() write) async {
    _submitted = true;
    if (reminders.isEmpty || slot == null) {
      notifyListeners();
      return false;
    }

    isSaving = true;
    actionError = null;
    notifyListeners();

    try {
      final account = await authService.loadUser();
      final managed = await service.getManageableApartments();
      final propertyId = existing?.apartmentId ?? apartment?.id;
      if (_disposed ||
          account?.isReady != true ||
          !managed.any((item) => item.id == propertyId)) {
        actionError = 'You do not manage this property.';
        notifyListeners();
        return false;
      }

      // The slot may have been taken meanwhile (on another phone) or its
      // day may have become today (form left open past midnight).
      _scheduled = _onlyScheduled(await service.getMyRequests());
      if (slotState(slot!) != SlotState.free) {
        actionError =
            'This time slot is no longer available. Choose another one.';
        slot = null;
        return false;
      }
      savedId = await write();
      return true;
    } catch (e) {
      actionError = 'Could not save the service. Please try again.';
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  List<MaintenanceRequest> _onlyScheduled(List<MaintenanceRequest> requests) =>
      requests.where((request) => !request.isCancelled).toList();
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
