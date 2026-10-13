/// US-11: a service error that the ViewModel can display unchanged.
class DocumentException implements Exception {
  const DocumentException(this.message);
  final String message;
  @override
  String toString() => message;
}
