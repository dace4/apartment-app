/// Form validators used by several screens. Each returns an error message,
/// or null when the value is valid.
abstract final class Validators {
  static const minPasswordLength = 8;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email address.';
    if (!_emailPattern.hasMatch(email)) return 'Enter a valid email address.';
    return null;
  }

  /// Only checks that a password was typed, for the log in form.
  static String? requiredPassword(String? value) {
    if (value == null || value.isEmpty) return 'Enter your password.';
    return null;
  }

  /// Checks the strength of a new password, for the registration form.
  static String? newPassword(String? value) {
    if (value == null || value.isEmpty) return 'Enter a password.';
    if (value.length < minPasswordLength) {
      return 'Use at least $minPasswordLength characters.';
    }
    return null;
  }

  // Application form. firestore.rules checks the same limits.
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

  static String? applicationMessage(String? value) {
    if ((value?.trim() ?? '').length > messageLimit) {
      return 'Use at most $messageLimit characters.';
    }
    return null;
  }

  /// The move-in date cannot be in the past, except when it is the
  /// [initial] date kept from the original application.
  static String? moveInDate(DateTime? value, {DateTime? initial}) {
    if (value == null) return 'Choose a move-in date.';
    if (initial != null && dateOnly(value) == dateOnly(initial)) return null;
    if (dateOnly(value).isBefore(dateOnly(DateTime.now()))) {
      return 'Choose today or a later date.';
    }
    return null;
  }

  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
