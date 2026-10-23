import 'package:cloud_firestore/cloud_firestore.dart';

/// US-17: what kind of repair or maintenance is needed.
enum MaintenanceCategory {
  plumbing('Plumbing'),
  electrical('Electrical'),
  heating('Heating'),
  appliances('Appliances'),
  other('Other');

  const MaintenanceCategory(this.label);
  final String label;

  /// Unknown values are shown as "Other" instead of crashing the list.
  static MaintenanceCategory fromName(Object? name) => values.firstWhere(
    (category) => category.name == name,
    orElse: () => MaintenanceCategory.other,
  );
}

/// US-17: the stored status. "Done" is not stored: a scheduled service is
/// done once its time slot has ended (see [MaintenanceRequest.isDone]).
enum MaintenanceStatus {
  scheduled('Scheduled'),
  cancelled('Cancelled');

  const MaintenanceStatus(this.label);
  final String label;

  static MaintenanceStatus fromName(Object? name) => values.firstWhere(
    (status) => status.name == name,
    orElse: () => MaintenanceStatus.scheduled,
  );
}

/// US-17: when the in-app reminder appears before the service. Ordered from
/// the earliest to the latest reminder; the banner relies on this order.
enum MaintenanceReminder {
  oneDay('1 day before', Duration(days: 1)),
  oneHour('1 hour before', Duration(hours: 1)),
  fiveMinutes('5 minutes before', Duration(minutes: 5));

  const MaintenanceReminder(this.label, this.before);
  final String label;
  final Duration before;
}

/// US-17: a repair or maintenance service booked in a 30-minute time slot.
class MaintenanceRequest {
  const MaintenanceRequest({
    required this.id,
    required this.userId,
    required this.apartmentId,
    required this.apartmentTitle,
    required this.category,
    required this.description,
    required this.slotStart,
    required this.reminders,
    required this.status,
  });

  static const slotLength = Duration(minutes: 30);

  final String id;

  /// The property manager who booked it.
  final String userId;
  final String apartmentId;

  /// Stored with the request so the list does not need to load every
  /// apartment.
  final String apartmentTitle;
  final MaintenanceCategory category;
  final String description;
  final DateTime slotStart;
  final Set<MaintenanceReminder> reminders;
  final MaintenanceStatus status;

  DateTime get slotEnd => slotStart.add(slotLength);

  bool get isCancelled => status == MaintenanceStatus.cancelled;

  /// A scheduled service is done once its time slot has ended.
  bool isDone(DateTime now) => !isCancelled && !now.isBefore(slotEnd);

  /// It can be rescheduled or cancelled until the service starts. The
  /// Firestore rules enforce the same limit on the server.
  bool canChange(DateTime now) => !isCancelled && now.isBefore(slotStart);

  /// The reminders whose time has come, until the service starts.
  List<MaintenanceReminder> dueReminders(DateTime now) {
    if (!canChange(now)) return const [];
    return reminders
        .where((reminder) => !now.isBefore(slotStart.subtract(reminder.before)))
        .toList();
  }

  /// US-17.3: the due reminder closest to the service, or null. When the
  /// app was closed while several became due, only this one is shown and
  /// notified, so the user is not flooded with old reminders.
  MaintenanceReminder? latestDueReminder(DateTime now) {
    final due = dueReminders(now);
    // MaintenanceReminder.values goes from the earliest to the latest.
    return due.isEmpty
        ? null
        : due.reduce((a, b) => a.index > b.index ? a : b);
  }

  factory MaintenanceRequest.fromMap(String id, Map<String, dynamic> map) {
    final reminderNames = (map['reminders'] as List?) ?? const [];
    return MaintenanceRequest(
      id: id,
      userId: map['userId'] as String,
      apartmentId: map['apartmentId'] as String,
      apartmentTitle: map['apartmentTitle'] as String,
      category: MaintenanceCategory.fromName(map['category']),
      description: map['description'] as String? ?? '',
      slotStart: (map['slotStart'] as Timestamp).toDate(),
      reminders: MaintenanceReminder.values
          .where((reminder) => reminderNames.contains(reminder.name))
          .toSet(),
      status: MaintenanceStatus.fromName(map['status']),
    );
  }
}
