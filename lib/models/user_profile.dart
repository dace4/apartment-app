import 'user_role.dart';

/// US-06: the `users/{uid}` document. Full name and phone are optional:
/// accounts created before they were asked have only roles. They pre-fill
/// the forms that ask for them.
class UserProfile {
  const UserProfile({required this.roles, this.fullName, this.phone});

  final Set<UserRole> roles;
  final String? fullName;
  final String? phone;

  factory UserProfile.fromMap(Map<String, dynamic>? map) {
    return UserProfile(
      roles: UserRole.fromNames(map?['roles']),
      fullName: map?['fullName'] as String?,
      phone: map?['phone'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roles': UserRole.values
          .where(roles.contains)
          .map((r) => r.name)
          .toList(),
      if (fullName != null) 'fullName': fullName!.trim(),
      if (phone != null) 'phone': phone!.trim(),
    };
  }
}
