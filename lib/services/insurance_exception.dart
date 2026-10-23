/// US-19: thrown by [InsuranceService] with a message that can be shown to
/// the user.
class InsuranceException implements Exception {
  const InsuranceException(this.message);
  final String message;
  @override
  String toString() => message;
}
