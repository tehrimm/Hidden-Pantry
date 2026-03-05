import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/utils/auth_validator.dart';

void main() {
  group('AuthValidator.validateGmailUsername', () {
    test('returns error for empty username', () {
      expect(AuthValidator.validateGmailUsername(''), '*field is required');
      expect(AuthValidator.validateGmailUsername(null), '*field is required');
    });

    test('returns error for too short username', () {
      expect(AuthValidator.validateGmailUsername('ab'), '*invalid email');
    });

    test('returns error for invalid characters', () {
      expect(AuthValidator.validateGmailUsername('user!'), '*invalid email');
      expect(AuthValidator.validateGmailUsername('user#123'), '*invalid email');
    });

    test('returns null for valid username', () {
      expect(AuthValidator.validateGmailUsername('user.name_1'), isNull);
      expect(AuthValidator.validateGmailUsername('johndoe'), isNull);
    });
  });

  group('AuthValidator.validateEmail', () {
    test('returns error for empty email', () {
      expect(AuthValidator.validateEmail(''), '*email field is required');
    });

    test('returns error for email without @', () {
      expect(AuthValidator.validateEmail('invalidemail'), '*incorrect email');
    });

    test('returns null for valid email', () {
      expect(AuthValidator.validateEmail('test@example.com'), isNull);
    });
  });

  group('AuthValidator.validatePassword', () {
    test('returns error for empty password', () {
      expect(AuthValidator.validatePassword(''), '*password field is required');
    });

    test('returns error for weak password', () {
      expect(AuthValidator.validatePassword('123'),
          '*password must be at least 8 characters');
    });

    test('returns null for valid password', () {
      expect(AuthValidator.validatePassword('password123'), isNull);
    });
  });

  group('AuthValidator.validateFullName', () {
    test('returns error for empty name', () {
      expect(AuthValidator.validateFullName(''), '*field is required');
    });

    test('returns error for too short name', () {
      expect(AuthValidator.validateFullName('Jo'), '*invalid name');
    });

    test('returns error for invalid name format', () {
      expect(AuthValidator.validateFullName('123Name'), '*invalid name');
      expect(AuthValidator.validateFullName('!John'), '*invalid name');
    });

    test('returns null for valid name', () {
      expect(AuthValidator.validateFullName('John Doe'), isNull);
      expect(AuthValidator.validateFullName("O'Connor"), isNull);
    });
  });

  group('AuthValidator.validatePhone', () {
    test('returns error for empty phone', () {
      expect(AuthValidator.validatePhone(''), '*phone number is required');
    });

    test('returns error for invalid phone length', () {
      expect(AuthValidator.validatePhone('123'), '*enter valid number');
      expect(AuthValidator.validatePhone('1234567890123456'), '*enter valid number');
    });

    test('returns null for valid phone', () {
      expect(AuthValidator.validatePhone('1234567'), isNull);
      expect(AuthValidator.validatePhone('03001234567'), isNull);
      expect(AuthValidator.validatePhone('+92 300 1234567'), isNull);
    });
  });
}
