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
    this.fullName,
    this.phone,
  });

  final String id;
  final String email;
  final bool emailVerified;
  final Set<UserRole> roles;
  final bool rolesLoaded;
  final String? profileError;

  /// US-06: pre-fill the forms; null on accounts that never gave them.
  final String? fullName;
  final String? phone;

  /// The admin has every role, so every feature lets them in.
  bool get isAdmin => roles.contains(UserRole.admin);
  bool get isBuyer => isAdmin || roles.contains(UserRole.buyer);
  bool get isRenter => isAdmin || roles.contains(UserRole.renter);
  bool get isConsumer => isBuyer || isRenter;
  bool get isHomeowner => isAdmin || roles.contains(UserRole.homeowner);
  bool get hasManagementRole => isHomeowner;
  bool get isReady => emailVerified && hasRoles;

  bool get hasRoles => rolesLoaded && profileError == null && roles.isNotEmpty;

  bool get hasContactDetails => fullName != null && phone != null;
}
