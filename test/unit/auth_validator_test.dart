import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/utils/auth_validator.dart';

void main() {
  group('AuthValidator', () {
    test('validateEmail detects required and invalid', () {
      expect(AuthValidator.validateEmail(''), '*email field is required');
      expect(AuthValidator.validateEmail('foo'), '*incorrect email');
      expect(AuthValidator.validateEmail('foo@bar'), '*incorrect email');
      expect(AuthValidator.validateEmail('foo@bar.com'), isNull);
    });

    test('validatePassword enforces length', () {
      expect(AuthValidator.validatePassword(''), '*password field is required');
      expect(AuthValidator.validatePassword('1234567'), '*password must be at least 8 characters');
      expect(AuthValidator.validatePassword('12345678'), isNull);
    });

    test('validateFullName basic rules', () {
      expect(AuthValidator.validateFullName(''), '*field is required');
      expect(AuthValidator.validateFullName('A'), '*invalid name');
      expect(AuthValidator.validateFullName('John Doe'), isNull);
    });

    test('validatePhone basic rules', () {
      expect(AuthValidator.validatePhone(''), '*phone number is required');
      expect(AuthValidator.validatePhone('12345'), '*enter valid number');
      expect(AuthValidator.validatePhone('1234567'), isNull);
    });

    test('capitalizeName formats properly', () {
      expect(AuthValidator.capitalizeName('john DOE'), 'John Doe');
      expect(AuthValidator.capitalizeName(''), '');
    });
  });
}

