import 'package:firebase_auth/firebase_auth.dart';

/// User.reload() updates the user object; rules read claims in the ID token.
Future<void> refreshVerifiedSession() async {
  final user = FirebaseAuth.instance.currentUser;
  // Email verification can change after the original token was issued.
  // Force a fresh token so database rules see the updated email_verified claim.
  if (user != null && user.emailVerified) {
    await user.getIdToken(true);
  }
}
