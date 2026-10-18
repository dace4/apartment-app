class ListingException implements Exception {
  const ListingException(this.message);
  final String message;
  @override
  String toString() => message;
}
