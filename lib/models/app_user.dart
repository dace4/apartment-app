import 'user_role.dart';

/// The signed-in user and their US-06 role profile.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.emailVerified,
    this.roles = const {},
    this.rolesLoaded = true,
    this.profileError,
  });

  final String id;
  final String email;
  final bool emailVerified;
  final Set<UserRole> roles;
  final bool rolesLoaded;
  final String? profileError;

  bool get isBuyer => roles.contains(UserRole.buyer);
  bool get isRenter => roles.contains(UserRole.renter);
  bool get isConsumer => isBuyer || isRenter;
  bool get isHomeowner => roles.contains(UserRole.homeowner);
  bool get isPropertyManager => roles.contains(UserRole.propertyManager);
  bool get hasManagementRole => isHomeowner || isPropertyManager;
  bool get isReady => emailVerified && hasRoles;

  bool get hasRoles => rolesLoaded && profileError == null && roles.isNotEmpty;
}
