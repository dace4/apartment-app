/// US-06: selectable personas; selecting a role never assigns a property.
enum UserRole {
  buyer('Buyer'),
  renter('Renter'),
  homeowner('Homeowner'),

  /// Maintains the app and can open every feature. Granted only in the
  /// Firebase console: firestore.rules refuse it from the app.
  admin('Admin');

  const UserRole(this.label);
  final String label;

  /// The roles a user may choose themselves (never Admin).
  static const selectable = [buyer, renter, homeowner];

  /// Invalid legacy profiles require selection again, never partial privileges.
  static Set<UserRole> fromNames(Object? value) {
    if (value is! List || value.isEmpty || value.length > values.length) {
      return {};
    }
    final names = values.map((role) => role.name).toSet();
    if (value.any((name) => !names.contains(name)) ||
        value.toSet().length != value.length) {
      return {};
    }
    return Set.unmodifiable(value.map((name) => values.byName(name as String)));
  }
}
