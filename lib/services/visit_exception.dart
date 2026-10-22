/// US-20: thrown by [VisitService] with a message that can be shown to the
/// user.
class VisitException implements Exception {
  const VisitException(this.message);
  final String message;
  @override
  String toString() => message;
}
