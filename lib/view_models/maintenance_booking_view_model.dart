import 'package:flutter/foundation.dart';

import '../models/apartment.dart';
import '../models/maintenance_request.dart';
import '../services/apartment_service.dart';
import '../services/maintenance_service.dart';
import '../utils/maintenance_schedule.dart';

/// What a time slot shows in the booking flow.
enum SlotState {
  free,

  /// Another of the user's services already uses it.
  booked,

  /// The service being rescheduled is in this slot.
  current,

  /// In the past, less than 24 hours away, or more than 60 days away.
  unavailable,
}

/// US-17: book a new repair or maintenance service, or reschedule one.
class MaintenanceBookingViewModel extends ChangeNotifier {
  final ApartmentService apartmentService = ApartmentService();
  final MaintenanceService service = MaintenanceService();

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
        apartments = await apartmentService.getApartments()
          ..sort((a, b) => a.title.compareTo(b.title));
      } else {
        existing = await service.getRequest(rescheduleId);
        if (existing == null) {
          errorMessage = 'This maintenance service does not exist.';
        } else if (!existing!.canChange(DateTime.now())) {
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
  DateTime get firstDate => MaintenanceSchedule.firstDate(DateTime.now());
  DateTime get lastDate => MaintenanceSchedule.lastDate(DateTime.now());
  DateTime get pickerInitialDate =>
      date ?? MaintenanceSchedule.firstSelectableDay(DateTime.now());
  bool isSelectableDay(DateTime day) =>
      MaintenanceSchedule.isSelectableDay(day, DateTime.now());

  /// The times that can be booked on the chosen date, for the dropdown.
  /// Booked, current and too-soon slots are left out.
  List<DateTime> get availableSlots => date == null
      ? const []
      : MaintenanceSchedule.slotsFor(
          date!,
        ).where((slot) => slotState(slot) == SlotState.free).toList();

  SlotState slotState(DateTime slot) {
    if (existing != null && slot == existing!.slotStart) {
      return SlotState.current;
    }
    if (!MaintenanceSchedule.isBookable(slot, DateTime.now())) {
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

  void selectDate(DateTime value) {
    date = MaintenanceSchedule.dateOnly(value);
    slot = null;
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
      // The slot may have been taken meanwhile (on another phone) or may
      // now be less than 24 hours away.
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
}
