import '../models/maintenance_request.dart';

/// US-17: when a repair or maintenance service can be booked.
/// - Monday to Friday, consecutive slots of [MaintenanceRequest.slotLength]
///   (30 minutes) from 08:00 to 12:00 and from 13:00 to 17:00.
/// - From tomorrow up to 60 days ahead. On a day after today, every slot
///   from 08:00 to 17:00 can be booked.
abstract final class MaintenanceSchedule {
  /// Working hours as (start hour, end hour); 12:00–13:00 is the lunch break.
  static const workingHours = [(8, 12), (13, 17)];
  static const maxDaysAhead = 60;

  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static bool isWorkday(DateTime date) => date.weekday <= DateTime.friday;

  /// The slots of a weekday, one after the other, none on weekends.
  static List<DateTime> slotsFor(DateTime date) {
    if (!isWorkday(date)) return const [];
    final slots = <DateTime>[];
    for (final (startHour, endHour) in workingHours) {
      var slot = DateTime(date.year, date.month, date.day, startHour);
      final end = DateTime(date.year, date.month, date.day, endHour);
      // A slot must end by the end of the working period.
      while (!slot.add(MaintenanceRequest.slotLength).isAfter(end)) {
        slots.add(slot);
        slot = slot.add(MaintenanceRequest.slotLength);
      }
    }
    return slots;
  }

  /// The first day that can be booked: tomorrow.
  static DateTime firstDate(DateTime now) =>
      DateTime(now.year, now.month, now.day + 1);

  /// The last day that can be booked.
  static DateTime lastDate(DateTime now) =>
      DateTime(now.year, now.month, now.day + maxDaysAhead);

  /// Whether a slot is on a day from tomorrow up to 60 days ahead.
  static bool isBookable(DateTime slot, DateTime now) =>
      !dateOnly(slot).isBefore(firstDate(now)) &&
      !dateOnly(slot).isAfter(lastDate(now));

  /// Whether the date picker lets the user choose this day.
  static bool isSelectableDay(DateTime day, DateTime now) =>
      slotsFor(day).any((slot) => isBookable(slot, now));

  /// The first day the date picker can open on.
  static DateTime firstSelectableDay(DateTime now) {
    var day = firstDate(now);
    while (!isSelectableDay(day, now)) {
      day = DateTime(day.year, day.month, day.day + 1);
    }
    return day;
  }
}
