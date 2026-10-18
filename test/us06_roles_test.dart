import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appartment_app_group_2/models/app_user.dart';
import 'package:appartment_app_group_2/models/user_role.dart';
import 'package:appartment_app_group_2/services/auth_service.dart';
import 'package:appartment_app_group_2/services/user_profile_service.dart';
import 'package:appartment_app_group_2/view_models/auth_view_model.dart';
import 'package:appartment_app_group_2/view_models/register_view_model.dart';
import 'package:appartment_app_group_2/views/auth/choose_roles_view.dart';

class RoleAuth extends Fake implements AuthService {
  final users = StreamController<AppUser?>.broadcast();
  Set<UserRole>? saved;
  bool fail = false;
  int registrations = 0;
  @override
  Stream<AppUser?> userChanges() => users.stream;
  @override
  Future<void> saveRoles(Set<UserRole> roles) async {
    if (fail) {
      throw const AuthException('Could not save your roles. Please try again.');
    }
    saved = roles;
  }

  @override
  Future<void> register(
    String email,
    String password,
    Set<UserRole> roles,
  ) async {
    registrations++;
    if (roles.isEmpty) throw const AuthException('Choose at least one role.');
    await saveRoles(roles);
  }

  @override
  Future<void> signOut() async => users.add(null);
}

void main() {
  test(
    'US-06 all 15 combinations persist and survive a fresh profile read',
    () async {
      final db = FakeFirebaseFirestore();
      final profiles = UserProfileService(firestore: db);
      for (var mask = 1; mask < 16; mask++) {
        final roles = {
          for (var i = 0; i < 4; i++)
            if (mask & (1 << i) != 0) UserRole.values[i],
        };
        await profiles.saveRoles('account', roles);
        expect(
          await UserProfileService(firestore: db).watchRoles('account').first,
          roles,
        );
      }
      await expectLater(
        profiles.saveRoles('account', {}),
        throwsA(isA<AuthException>()),
      );
    },
  );

  test('US-06 missing, malformed and unknown legacy roles fail closed', () {
    for (final value in [
      null,
      [],
      ['admin'],
      ['buyer', 'admin'],
      ['buyer', 'buyer'],
      'buyer',
    ]) {
      expect(UserRole.fromNames(value), isEmpty);
    }
  });

  test(
    'US-06 edits require Save, reject empty roles and allow failed-save retry',
    () async {
      final auth = RoleAuth();
      final vm = AuthViewModel(service: auth);
      auth.users.add(
        const AppUser(id: 'a', email: 'a@test.ch', emailVerified: true),
      );
      await Future<void>.delayed(Duration.zero);
      expect(await vm.saveRoles(), false);
      vm.setRole(UserRole.buyer, true);
      vm.setRole(UserRole.homeowner, true);
      expect(auth.saved, null);
      auth.fail = true;
      expect(await vm.saveRoles(), false);
      expect(vm.selectedRoles, {UserRole.buyer, UserRole.homeowner});
      auth.fail = false;
      expect(await vm.saveRoles(), true);
      expect(auth.saved, {UserRole.buyer, UserRole.homeowner});
      auth.users.add(
        const AppUser(id: 'b', email: 'b@test.ch', emailVerified: true),
      );
      await Future<void>.delayed(Duration.zero);
      expect(vm.selectedRoles, isEmpty);
      vm.dispose();
      await auth.users.close();
    },
  );

  test('US-06 registration forwards multiple roles', () async {
    final auth = RoleAuth();
    final vm = RegisterViewModel(service: auth);
    vm.setRole(UserRole.renter, true);
    vm.setRole(UserRole.propertyManager, true);
    await vm.register('a@test.ch', 'password');
    expect(auth.saved, {UserRole.renter, UserRole.propertyManager});
    expect(auth.registrations, 1);
    vm.dispose();
    await auth.users.close();
  });

  testWidgets('US-06 profile loading/error gate exposes recovery controls', (
    tester,
  ) async {
    final auth = RoleAuth();
    final vm = AuthViewModel(service: auth);
    await tester.pumpWidget(MaterialApp(home: ChooseRolesView(viewModel: vm)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    auth.users.add(
      const AppUser(
        id: 'a',
        email: 'a@test.ch',
        emailVerified: true,
        profileError: 'Could not load your roles. Please retry.',
      ),
    );
    await tester.pump();
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
    expect(find.text('Save roles'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
    await auth.users.close();
  });
}
