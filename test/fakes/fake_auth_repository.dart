import 'package:appartment_app_group_2/features/auth/data/auth_repository.dart';

/// In-memory [AuthRepository] so widget tests don't need Firebase.
class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository({this.currentUser});

  @override
  AppUser? currentUser;

  /// Accounts that exist, by email, with their password.
  final Map<String, String> accounts = {};

  /// Emails a verification email was sent to.
  final List<String> verificationEmailsSent = [];

  @override
  Future<void> signIn({required String email, required String password}) async {
    if (accounts[email.trim()] != password) {
      throw const AuthException('Email or password is incorrect.');
    }
    currentUser = AppUser(
      id: email.trim(),
      email: email.trim(),
      emailVerified: true,
    );
    notifyListeners();
  }

  @override
  Future<void> register({
    required String email,
    required String password,
  }) async {
    final trimmed = email.trim();
    if (accounts.containsKey(trimmed)) {
      throw const AuthException('An account already exists for this email.');
    }
    accounts[trimmed] = password;
    currentUser = AppUser(id: trimmed, email: trimmed, emailVerified: false);
    verificationEmailsSent.add(trimmed);
    notifyListeners();
  }

  @override
  Future<void> sendEmailVerification() async {
    if (currentUser != null) verificationEmailsSent.add(currentUser!.email);
  }

  /// Simulates the user clicking the link in the verification email.
  void verifyEmail() {
    final user = currentUser!;
    currentUser = AppUser(id: user.id, email: user.email, emailVerified: true);
  }

  @override
  Future<void> reloadUser() async => notifyListeners();

  @override
  Future<void> signOut() async {
    currentUser = null;
    notifyListeners();
  }
}
