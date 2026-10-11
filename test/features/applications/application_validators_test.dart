import 'package:appartment_app_group_2/features/applications/models/rental_application.dart';
import 'package:appartment_app_group_2/features/applications/utils/application_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('full name is required and limited to 100 characters', () {
    expect(ApplicationValidators.fullName('  '), isNotNull);
    expect(ApplicationValidators.fullName('a' * 101), isNotNull);
    expect(ApplicationValidators.fullName('Anna Muster'), isNull);
  });

  test('phone accepts Swiss formats and rejects text', () {
    expect(ApplicationValidators.phone('+41 79 123 45 67'), isNull);
    expect(ApplicationValidators.phone('027 606 85 11'), isNull);
    expect(ApplicationValidators.phone('call me'), isNotNull);
    expect(ApplicationValidators.phone(''), isNotNull);
  });

  test('occupants must be a number from 1 to 10', () {
    expect(ApplicationValidators.occupants('0'), isNotNull);
    expect(ApplicationValidators.occupants('11'), isNotNull);
    expect(ApplicationValidators.occupants('two'), isNotNull);
    expect(ApplicationValidators.occupants('1'), isNull);
    expect(ApplicationValidators.occupants('10'), isNull);
  });

  test('move-in date must be today or later', () {
    final today = DateTime(2026, 10, 11, 15, 30);
    expect(ApplicationValidators.moveInDate(null, today), isNotNull);
    expect(
      ApplicationValidators.moveInDate(DateTime(2026, 10, 10), today),
      isNotNull,
    );
    expect(
      ApplicationValidators.moveInDate(DateTime(2026, 10, 11), today),
      isNull,
    );
  });

  test('an application can change only while open and within 5 days', () {
    final submitted = DateTime(2026, 10, 1, 12);
    RentalApplication application(ApplicationStatus status) =>
        RentalApplication(
          id: 'a1',
          userId: 'u1',
          apartmentId: '1',
          apartmentTitle: 'Apartment',
          details: ApplicationDetails(
            fullName: 'Anna',
            phone: '+41 79 123 45 67',
            moveInDate: DateTime(2026, 11, 1),
            occupants: 1,
          ),
          status: status,
          submittedAt: submitted,
        );

    final open = application(ApplicationStatus.submitted);
    expect(open.canChange(DateTime(2026, 10, 6, 11, 59)), isTrue);
    expect(open.canChange(DateTime(2026, 10, 6, 12)), isFalse);
    expect(
      application(ApplicationStatus.underReview).canChange(submitted),
      isTrue,
    );
    expect(
      application(ApplicationStatus.withdrawn).canChange(submitted),
      isFalse,
    );
    expect(
      application(ApplicationStatus.accepted).canChange(submitted),
      isFalse,
    );
  });
}
