/// US-06: selectable personas; selecting a role never assigns a property.
enum UserRole {
  buyer('Buyer'),
  renter('Renter'),
  homeowner('Homeowner'),
  propertyManager('Property Manager');

  const UserRole(this.label);
  final String label;

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
