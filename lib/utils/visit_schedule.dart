/// US-20: when an apartment can be visited. Every apartment has the same
/// slots; each slot can be booked by one visitor.
/// - Monday to Friday, two slots a day: 09:00–11:00 and 14:00–16:00
///   (see [Visit.slotLength]).
/// - From tomorrow up to 30 days ahead.
abstract final class VisitSchedule {
  /// Start hours of the morning and the afternoon slot.
  static const slotStartHours = [9, 14];
  static const maxDaysAhead = 30;

  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static bool isWorkday(DateTime date) => date.weekday <= DateTime.friday;

  /// The slots of a weekday, none on weekends.
  static List<DateTime> slotsFor(DateTime date) => isWorkday(date)
      ? [
          for (final hour in slotStartHours)
            DateTime(date.year, date.month, date.day, hour),
        ]
      : const [];

  /// The first day that can be booked: tomorrow.
  static DateTime firstDate(DateTime now) =>
      DateTime(now.year, now.month, now.day + 1);

  /// The last day that can be booked.
  static DateTime lastDate(DateTime now) =>
      DateTime(now.year, now.month, now.day + maxDaysAhead);

  /// Whether the calendar lets the user choose this day.
  static bool isSelectableDay(DateTime day, DateTime now) {
    final date = dateOnly(day);
    return isWorkday(date) &&
        !date.isBefore(firstDate(now)) &&
        !date.isAfter(lastDate(now));
  }

  /// Whether [slot] is one of the slots of a day that can be booked.
  static bool isBookable(DateTime slot, DateTime now) =>
      isSelectableDay(slot, now) && slotsFor(slot).contains(slot);

  /// The first day the calendar can open on.
  static DateTime firstSelectableDay(DateTime now) {
    var day = firstDate(now);
    while (!isWorkday(day)) {
      day = DateTime(day.year, day.month, day.day + 1);
    }
    return day;
  }

  /// ID of the document that reserves a slot, e.g. "abc123_20261027_0900".
  /// Only one document can have this ID, so a slot is never booked twice.
  static String slotId(String apartmentId, DateTime slotStart) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${apartmentId}_${slotStart.year}${twoDigits(slotStart.month)}'
        '${twoDigits(slotStart.day)}_${twoDigits(slotStart.hour)}'
        '${twoDigits(slotStart.minute)}';
  }
}
