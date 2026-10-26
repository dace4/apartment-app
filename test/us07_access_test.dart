import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:appartment_app_group_2/models/app_user.dart';
import 'package:appartment_app_group_2/models/apartment.dart';
import 'package:appartment_app_group_2/models/user_role.dart';
import 'package:appartment_app_group_2/router/app_routes.dart';
import 'package:appartment_app_group_2/services/document_service.dart';
import 'package:appartment_app_group_2/services/file_picker_service.dart';
import 'package:appartment_app_group_2/view_models/auth_view_model.dart';
import 'package:appartment_app_group_2/view_models/documents_view_model.dart';
import 'package:appartment_app_group_2/views/profile/profile_view.dart';

import 'us06_roles_test.dart' show RoleAuth;

class NoDocumentAccess extends Fake implements DocumentService {}

class NoFilePicker extends Fake implements FilePickerService {}

AppUser account(
  Set<UserRole> roles, {
  String id = 'account',
  bool verified = true,
  bool loaded = true,
  String? error,
}) => AppUser(
  id: id,
  email: '$id@test.ch',
  emailVerified: verified,
  roles: roles,
  rolesLoaded: loaded,
  profileError: error,
);
Apartment property({String? ownerId, Set<String> managers = const {}}) =>
    Apartment(
      id: 'a',
      title: 'Apartment',
      address: 'Street',
      city: 'Sion',
      listingType: ListingType.rent,
      price: 1000,
      rooms: 3,
      surface: 60,
      imageUrl: '',
      description: '',
      ownerId: ownerId,
      managerIds: managers,
    );

void main() {
  late RoleAuth auth;
  late AuthViewModel vm;
  Future<void> emit(AppUser? user) async {
    auth.users.add(user);
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() {
    auth = RoleAuth();
    vm = AuthViewModel(service: auth);
  });
  tearDown(() async {
    vm.dispose();
    await auth.users.close();
  });

  test('US-07 all 15 role unions implement the agreed access matrix', () async {
    for (var mask = 1; mask < 16; mask++) {
      final roles = {
        for (var i = 0; i < 4; i++)
          if (mask & (1 << i) != 0) UserRole.values[i],
      };
      await emit(account(roles));
      // The admin has every role.
      bool has(UserRole role) =>
          roles.contains(role) || roles.contains(UserRole.admin);
      final consumer = has(UserRole.buyer) || has(UserRole.renter);
      for (final path in [
        AppRoutes.apartments,
        AppRoutes.profile,
        AppRoutes.notifications,
      ]) {
        expect(vm.canAccess(path), true);
      }
      for (final path in [
        AppRoutes.compare,
        AppRoutes.favourites,
        AppRoutes.savedSearches,
        AppRoutes.documents,
        AppRoutes.documentReview('d'),
        AppRoutes.signature,
        AppRoutes.applications,
        AppRoutes.editApplication('a'),
        AppRoutes.apply('p'),
        AppRoutes.contactAdvertiser('p'),
      ]) {
        expect(vm.canAccess(path), consumer, reason: '$roles: $path');
      }
      expect(
        vm.canAccess(AppRoutes.applyImmediately('p')),
        has(UserRole.renter),
      );
      expect(vm.canAccess(AppRoutes.mortgage), has(UserRole.buyer));
      expect(vm.canAccess(AppRoutes.marketTrends), has(UserRole.buyer));
      expect(vm.canAccess(AppRoutes.insurance), has(UserRole.renter));
      expect(vm.canAccess(AppRoutes.contractors), has(UserRole.homeowner));
      expect(vm.canAccess(AppRoutes.createApartment), has(UserRole.homeowner));
      // App maintenance is for admins only.
      expect(
        vm.canAccess(AppRoutes.maintenance),
        roles.contains(UserRole.admin),
      );
      expect(vm.canAccess(AppRoutes.inbox), has(UserRole.homeowner));
    }
  });

  test(
    'US-07 email gate precedes role selection and never accepts profile errors',
    () async {
      expect(vm.redirectFor(AppRoutes.documents), AppRoutes.login);
      await emit(account({UserRole.renter}, verified: false));
      expect(vm.redirectFor(AppRoutes.documents), AppRoutes.verifyEmail);
      expect(vm.redirectFor(AppRoutes.chooseRoles), AppRoutes.verifyEmail);
      await emit(account({}));
      expect(vm.redirectFor(AppRoutes.documents), AppRoutes.chooseRoles);
      await emit(account({UserRole.buyer}, loaded: false));
      expect(vm.redirectFor(AppRoutes.documents), AppRoutes.chooseRoles);
      await emit(account({UserRole.renter}, error: 'Read failed'));
      expect(vm.redirectFor(AppRoutes.documents), AppRoutes.chooseRoles);
      await emit(account({UserRole.renter}));
      expect(vm.redirectFor(AppRoutes.login), AppRoutes.apartments);
      expect(vm.redirectFor(AppRoutes.verifyEmail), AppRoutes.apartments);
      expect(vm.redirectFor(AppRoutes.documents), null);
      await emit(account({UserRole.homeowner}));
      expect(vm.redirectFor(AppRoutes.documents), AppRoutes.apartments);
      await emit(null);
      expect(vm.canAccess(AppRoutes.documents), false);
    },
  );

  test(
    'during app maintenance only admins pass, after the email gate',
    () async {
      await emit(null);
      expect(vm.redirectFor(AppRoutes.login, appDown: true), null);
      await emit(account({UserRole.renter}, verified: false));
      expect(
        vm.redirectFor(AppRoutes.apartments, appDown: true),
        AppRoutes.verifyEmail,
      );
      await emit(account({UserRole.renter, UserRole.homeowner}));
      expect(
        vm.redirectFor(AppRoutes.apartments, appDown: true),
        AppRoutes.appMaintenance,
      );
      expect(vm.redirectFor(AppRoutes.appMaintenance, appDown: true), null);
      // When the window ends, the maintenance page sends the user back.
      expect(vm.redirectFor(AppRoutes.appMaintenance), AppRoutes.apartments);
      await emit(account({UserRole.admin}));
      expect(vm.redirectFor(AppRoutes.maintenance, appDown: true), null);
      expect(
        vm.redirectFor(AppRoutes.appMaintenance, appDown: true),
        AppRoutes.apartments,
      );
    },
  );

  test(
    'US-07 property relationships require the matching role and UID',
    () async {
      await emit(account({UserRole.homeowner}));
      expect(vm.canManage(property(ownerId: 'account')), true);
      expect(vm.canManage(property(managers: {'account'})), false);
      expect(vm.canManage(property()), false);
      // The admin manages the apartments they own or are assigned to.
      await emit(account({UserRole.admin}));
      expect(vm.canManage(property(ownerId: 'account')), true);
      expect(vm.canManage(property(managers: {'account'})), true);
      await emit(account({UserRole.homeowner, UserRole.admin}));
      expect(
        vm.canManage(property(ownerId: 'other', managers: {'other'})),
        false,
      );
      expect(vm.canManage(property(ownerId: 'account')), true);
      await emit(account({UserRole.renter}));
      expect(
        vm.canManage(property(ownerId: 'account', managers: {'account'})),
        false,
      );
      final copied = property(
        ownerId: 'owner',
        managers: {'manager'},
      ).copyWith();
      expect(copied.ownerId, 'owner');
      expect(copied.managerIds, {'manager'});
      expect(copied.toMap().containsKey('ownerId'), false);
    },
  );

  test(
    'US-07 ViewModel stops file actions after live permission revocation',
    () async {
      await emit(account({UserRole.renter}));
      final documents = DocumentsViewModel(
        service: NoDocumentAccess(),
        picker: NoFilePicker(),
        canAccess: () => vm.canAccess(AppRoutes.documents),
      );
      await emit(account({UserRole.homeowner}));
      // The fakes throw if called; neither Firebase nor the picker should be used.
      documents.listenToDocuments();
      expect(documents.errorMessage, isNotNull);
      await documents.pickAndUpload();
      expect(documents.actionError, isNotNull);
      expect(documents.documents, isEmpty);
      documents.dispose();
    },
  );

  testWidgets(
    'US-07 a protected deep link redirects after role removal and logout',
    (tester) async {
      auth.users.add(account({UserRole.renter}));
      await tester.pump();
      final router = GoRouter(
        initialLocation: AppRoutes.documents,
        refreshListenable: vm,
        redirect: (context, state) => vm.redirectFor(state.matchedLocation),
        routes: [
          for (final path in [
            AppRoutes.login,
            AppRoutes.verifyEmail,
            AppRoutes.chooseRoles,
            AppRoutes.apartments,
            AppRoutes.documents,
          ])
            GoRoute(
              path: path,
              builder: (context, state) => Scaffold(body: Text(path)),
            ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text(AppRoutes.documents), findsOneWidget);
      auth.users.add(account({UserRole.homeowner}));
      await tester.pumpAndSettle();
      expect(find.text(AppRoutes.apartments), findsOneWidget);
      auth.users.add(null);
      await tester.pumpAndSettle();
      expect(find.text(AppRoutes.login), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
    },
  );

  testWidgets(
    'US-06/07 Profile role checkboxes save only explicit choices on a small screen',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      auth.users.add(account({UserRole.renter}));
      await tester.pump();
      await tester.pumpWidget(MaterialApp(home: ProfileView(viewModel: vm)));
      // US-06: the roles are in a section that opens on tap.
      expect(find.text('Buyer'), findsNothing);
      await tester.tap(find.text('Your roles'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buyer'));
      await tester.pump();
      expect(auth.saved, null);
      await tester.ensureVisible(find.text('Save roles'));
      await tester.tap(find.text('Save roles'));
      await tester.pumpAndSettle();
      expect(auth.saved, {UserRole.buyer, UserRole.renter});
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
