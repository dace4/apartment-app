import '../models/rental_application.dart';

/// Thrown by [ApplicationRepository] with a message that can be shown to the
/// user.
class ApplicationException implements Exception {
  const ApplicationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// US 16: submit, track, edit and withdraw the signed-in user's applications.
abstract class ApplicationRepository {
  const ApplicationRepository();

  /// Allocate the ID before submitting so a retry after a lost response
  /// confirms the first submission instead of creating a second one.
  String createApplicationId();

  /// The signed-in user's applications, newest first, updated live.
  Stream<List<RentalApplication>> watchMyApplications();

  /// One of the signed-in user's applications, or null when it does not exist.
  Stream<RentalApplication?> watchApplication(String id);

  /// Reads an application once, e.g. to pre-fill the edit form.
  Future<RentalApplication?> fetchApplication(String id);

  Future<void> submit({
    required String id,
    required String apartmentId,
    required String apartmentTitle,
    required ApplicationDetails details,
  });

  Future<void> update(String id, ApplicationDetails details);

  Future<void> withdraw(String id);
}

/// Never pretends to store an application when no backend is configured.
class UnconfiguredApplicationRepository extends ApplicationRepository {
  const UnconfiguredApplicationRepository();

  static const _unavailable = ApplicationException(
    'The application service is unavailable. Please try again later.',
  );

  @override
  String createApplicationId() => 'unconfigured';

  @override
  Stream<List<RentalApplication>> watchMyApplications() =>
      Stream.error(_unavailable);

  @override
  Stream<RentalApplication?> watchApplication(String id) =>
      Stream.error(_unavailable);

  @override
  Future<RentalApplication?> fetchApplication(String id) async =>
      throw _unavailable;

  @override
  Future<void> submit({
    required String id,
    required String apartmentId,
    required String apartmentTitle,
    required ApplicationDetails details,
  }) async => throw _unavailable;

  @override
  Future<void> update(String id, ApplicationDetails details) async =>
      throw _unavailable;

  @override
  Future<void> withdraw(String id) async => throw _unavailable;
}
