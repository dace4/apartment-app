/// Shared by the form and repository; the limits also appear in Firestore rules.
/// Returning null is Flutter's convention for a valid form field.
abstract final class MessageValidators {
  static const subjectLimit = 120;
  static const bodyLimit = 2000;

  static String? subject(String? value) {
    // Whitespace-only input must fail even when the field is not literally empty.
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter a subject.';
    if (text.length > subjectLimit) return 'Use at most 120 characters.';
    return null;
  }

  static String? body(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter your message.';
    if (text.length > bodyLimit) return 'Use at most 2000 characters.';
    return null;
  }
}
