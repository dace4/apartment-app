import 'package:appartment_app_group_2/features/auth/utils/auth_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('email', () {
    test('accepts a valid address, ignoring surrounding spaces', () {
      expect(AuthValidators.email(' anna@hevs.ch '), isNull);
    });

    test('rejects empty and malformed addresses', () {
      expect(AuthValidators.email(''), isNotNull);
      expect(AuthValidators.email(null), isNotNull);
      expect(AuthValidators.email('anna'), isNotNull);
      expect(AuthValidators.email('anna@hevs'), isNotNull);
      expect(AuthValidators.email('an na@hevs.ch'), isNotNull);
    });
  });

  group('newPassword', () {
    test('requires the minimum length', () {
      expect(AuthValidators.newPassword('1234567'), isNotNull);
      expect(AuthValidators.newPassword('12345678'), isNull);
    });

    test('rejects an empty password', () {
      expect(AuthValidators.newPassword(''), isNotNull);
      expect(AuthValidators.newPassword(null), isNotNull);
    });
  });

  test('requiredPassword only checks that a password was typed', () {
    expect(AuthValidators.requiredPassword(''), isNotNull);
    expect(AuthValidators.requiredPassword('x'), isNull);
  });
}
