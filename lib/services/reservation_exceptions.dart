import 'package:firebase_core/firebase_core.dart';

/// Thrown when the apartment is no longer available at reservation time.
class ApartmentUnavailableException implements Exception {
  const ApartmentUnavailableException();

  @override
  String toString() => 'ApartmentUnavailableException';
}

/// One place that turns a failed reservation into a user-facing message,
/// so the view models don't all guess "it may no longer be available".
String reservationErrorMessage(Object error) {
  if (error is ApartmentUnavailableException) {
    return 'This apartment has just been reserved by someone else.';
  }
  if (error is FirebaseException) {
    switch (error.code) {
      // Security rules reject the write when the listing is not available.
      case 'permission-denied':
        return 'This apartment is no longer available.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Could not reach the server. Check your connection and try again.';
    }
  }
  return 'Could not reserve the apartment. Please try again.';
}
