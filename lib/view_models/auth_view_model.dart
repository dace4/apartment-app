import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../models/user_role.dart';
import '../models/apartment.dart';
import '../router/app_routes.dart';

/// The signed-in user, shared by the whole app (see ARCHITECTURE.md §4).
/// The router listens to it to redirect on log in, log out and email
/// verification. Also used by the Verify email and Profile pages.
class AuthViewModel extends ChangeNotifier {
  AuthViewModel({AuthService? service}) : service = service ?? AuthService() {
    _listen();
  }

  final AuthService service;
  late final StreamSubscription<AppUser?> _subscription;
  AppUser? _user;
  Set<UserRole> selectedRoles = {};
  bool isSaving = false;
  String? actionError;

  void _listen() {
    _subscription = service.userChanges().listen((value) {
      // US-06: a new name or phone must not undo roles ticked but not saved.
      final rolesChanged =
          value?.id != _user?.id || !setEquals(value?.roles, _user?.roles);
      _user = value;
      if (rolesChanged) {
        selectedRoles = {...?value?.roles};
        actionError = null;
      }
      notifyListeners();
    });
  }

  Future<void> retryProfile() async {
    await _subscription.cancel();
    _listen();
  }

  void setRole(UserRole role, bool selected) {
    // Admin is granted in the Firebase console and kept on every save.
    if (!UserRole.selectable.contains(role)) return;
    selectedRoles = {...selectedRoles};
    if (selected) {
      selectedRoles.add(role);
    } else {
      selectedRoles.remove(role);
    }
    actionError = null;
    notifyListeners();
  }

  Future<bool> saveRoles() async {
    if (isSaving) return false;
    if (selectedRoles.isEmpty) {
      actionError = 'Choose at least one role.';
      notifyListeners();
      return false;
    }
    isSaving = true;
    actionError = null;
    notifyListeners();
    try {
      await service.saveRoles({...selectedRoles});
      return true;
    } on AuthException catch (e) {
      actionError = e.message;
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  bool isLoading = false;

  /// Feedback shown on the Verify email page (sent again, not verified yet…).
  String? feedbackMessage;

  AppUser? get user => _user;

  // US-07: one policy for route guards and visible navigation actions.
  bool canAccess(String location) {
    final account = user;
    if (account == null || !account.isReady) return false;
    bool under(String path) =>
        location == path || location.startsWith('$path/');
    if (location == AppRoutes.createApartment) return account.isHomeowner;
    if (location.endsWith('/apply-immediately')) return account.isRenter;
    if (under(AppRoutes.applications) ||
        under(AppRoutes.documents) ||
        under(AppRoutes.signature) ||
        under(AppRoutes.favourites) ||
        under(AppRoutes.savedSearches) ||
        under(AppRoutes.visits) ||
        location == AppRoutes.compare ||
        location.endsWith('/apply') ||
        location.endsWith('/contact') ||
        location.endsWith('/visit')) {
      return account.isConsumer;
    }
    if (under(AppRoutes.mortgage) || under(AppRoutes.marketTrends)) {
      return account.isBuyer;
    }
    if (under(AppRoutes.insurance)) return account.isRenter;
    if (under(AppRoutes.contractors)) return account.isHomeowner;
    // Repair & maintenance schedules app downtime: admins only.
    if (under(AppRoutes.maintenance)) return account.isAdmin;
    if (under(AppRoutes.inbox)) return account.hasManagementRole;
    return true;
  }

  bool canManage(Apartment apartment) =>
      user?.isReady == true &&
      ((user!.isHomeowner && apartment.ownerId == user!.id) ||
          (user!.isAdmin && apartment.managerIds.contains(user!.id)));

  /// [appDown]: an app maintenance window is in progress. Only admins keep
  /// using the app; everyone else waits on the maintenance page.
  String? redirectFor(String location, {bool appDown = false}) {
    final onAuthPage =
        location == AppRoutes.login || location == AppRoutes.register;
    if (user == null) return onAuthPage ? null : AppRoutes.login;
    if (!user!.emailVerified) {
      return location == AppRoutes.verifyEmail ? null : AppRoutes.verifyEmail;
    }
    if (!user!.hasRoles) {
      return location == AppRoutes.chooseRoles ? null : AppRoutes.chooseRoles;
    }
    if (appDown && !user!.isAdmin) {
      return location == AppRoutes.appMaintenance
          ? null
          : AppRoutes.appMaintenance;
    }
    if (onAuthPage ||
        location == AppRoutes.appMaintenance ||
        location == AppRoutes.verifyEmail ||
        location == AppRoutes.chooseRoles ||
        !canAccess(location)) {
      return AppRoutes.apartments;
    }
    return null;
  }

  Future<void> resendVerificationEmail() async {
    isLoading = true;
    feedbackMessage = null;
    notifyListeners();

    try {
      await service.sendEmailVerification();
      feedbackMessage = 'Confirmation email sent again.';
    } on AuthException catch (e) {
      feedbackMessage = e.message;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// When the email is verified, the router leaves the Verify email page.
  Future<void> checkEmailVerified() async {
    isLoading = true;
    feedbackMessage = null;
    notifyListeners();

    try {
      await service.reloadUser();
      if (user?.emailVerified != true) {
        feedbackMessage =
            'Your email is not verified yet. Open the link in the email first.';
      }
    } on AuthException catch (e) {
      feedbackMessage = e.message;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// The router then goes back to the login page.
  Future<void> signOut() async {
    feedbackMessage = null;
    await service.signOut();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription.cancel();
    super.dispose();
  }
}
