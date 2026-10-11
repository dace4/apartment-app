/// Form validators for the application form. Each returns an error message,
/// or null when the value is valid. firestore.rules checks the same limits.
abstract final class ApplicationValidators {
  static const nameLimit = 100;
  static const messageLimit = 1000;
  static const maxOccupants = 10;

  static final _phonePattern = RegExp(r'^[+0-9 ()\-]{6,20}$');

  static String? fullName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Enter your full name.';
    if (name.length > nameLimit) return 'Use at most $nameLimit characters.';
    return null;
  }

  static String? phone(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) return 'Enter your phone number.';
    if (!_phonePattern.hasMatch(phone)) return 'Enter a valid phone number.';
    return null;
  }

  static String? occupants(String? value) {
    final count = int.tryParse(value?.trim() ?? '');
    if (count == null || count < 1 || count > maxOccupants) {
      return 'Enter a number from 1 to $maxOccupants.';
    }
    return null;
  }

  static String? message(String? value) {
    if ((value?.trim() ?? '').length > messageLimit) {
      return 'Use at most $messageLimit characters.';
    }
    return null;
  }

  /// The move-in date cannot be before [today] (date only).
  static String? moveInDate(DateTime? value, DateTime today) {
    if (value == null) return 'Choose a move-in date.';
    if (dateOnly(value).isBefore(dateOnly(today))) {
      return 'Choose today or a later date.';
    }
    return null;
  }

  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
