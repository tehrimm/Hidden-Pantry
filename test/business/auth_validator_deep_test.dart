import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/utils/auth_validator.dart';

void main() {
  group('Real Business Tests: AuthValidator Deep Cases', () {

    group('validateGmailUsername', () {
      test('Returns error for null input', () {
        expect(AuthValidator.validateGmailUsername(null), '*field is required');
      });

      test('Returns error for blank string', () {
        expect(AuthValidator.validateGmailUsername('  '), '*field is required');
      });

      test('Returns error for username shorter than 3 characters', () {
        expect(AuthValidator.validateGmailUsername('ab'), '*invalid email');
      });

      test('Returns null for minimum valid length (3 chars)', () {
        expect(AuthValidator.validateGmailUsername('abc'), null);
      });

      test('Returns error for special characters outside allowed set', () {
        expect(AuthValidator.validateGmailUsername('user@name'), '*invalid email');
        expect(AuthValidator.validateGmailUsername('user name'), '*invalid email');
        expect(AuthValidator.validateGmailUsername('user#1'), '*invalid email');
      });

      test('Returns null for allowed special characters (. and _)', () {
        expect(AuthValidator.validateGmailUsername('user.name'), null);
        expect(AuthValidator.validateGmailUsername('user_name'), null);
        expect(AuthValidator.validateGmailUsername('user.name_123'), null);
      });
    });

    group('validateEmail edge cases', () {
      test('Whitespace-only email returns required error', () {
        expect(AuthValidator.validateEmail('   '), '*email field is required');
      });

      test('Email with @ but no dot in domain fails', () {
        expect(AuthValidator.validateEmail('user@testcom'), '*incorrect email');
      });

      test('Email with dot before @ but no domain fails', () {
        expect(AuthValidator.validateEmail('user.@'), '*incorrect email');
      });

      test('Valid subdomain email passes', () {
        expect(AuthValidator.validateEmail('user@mail.company.com'), null);
      });

      test('Valid email with + alias passes', () {
        expect(AuthValidator.validateEmail('user+alias@gmail.com'), null);
      });
    });

    group('validatePassword edge cases', () {
      test('Whitespace-only password returns required error', () {
        expect(AuthValidator.validatePassword('   '), '*password must be at least 8 characters');
      });

      test('Exactly 8 characters passes', () {
        expect(AuthValidator.validatePassword('Ab1!5678'), null);
      });

      test('7 characters fails', () {
        expect(AuthValidator.validatePassword('1234567'), '*password must be at least 8 characters');
      });

      test('Long password passes', () {
        expect(AuthValidator.validatePassword('This_is_a_very_long_password_123!'), null);
      });
    });

    group('validateFullName edge cases', () {
      test('Exactly 2 characters fails', () {
        expect(AuthValidator.validateFullName('Jo'), '*invalid name');
      });

      test('Exactly 3 characters passes', () {
        expect(AuthValidator.validateFullName('Joe'), null);
      });

      test('Name starting with number fails', () {
        expect(AuthValidator.validateFullName('1Joe'), '*invalid name');
      });

      test('Name with hyphen is valid', () {
        expect(AuthValidator.validateFullName('Mary-Jane'), null);
      });

      test('Name with apostrophe is valid', () {
        expect(AuthValidator.validateFullName("O'Brien"), null);
      });

      test('Name with period is valid (e.g. Dr. Jane)', () {
        expect(AuthValidator.validateFullName('Jane Doe'), null);
      });
    });

    group('validatePhone edge cases', () {
      test('7 digits passes (minimum)', () {
        expect(AuthValidator.validatePhone('1234567'), null);
      });

      test('6 digits fails (below minimum)', () {
        expect(AuthValidator.validatePhone('123456'), '*enter valid number');
      });

      test('15 digits passes (maximum)', () {
        expect(AuthValidator.validatePhone('123456789012345'), null);
      });

      test('16 digits fails (above maximum)', () {
        expect(AuthValidator.validatePhone('1234567890123456'), '*enter valid number');
      });

      test('Strips non-digits before counting', () {
        // "+92 300 1234567" has 12 digits
        expect(AuthValidator.validatePhone('+92 300 1234567'), null);
      });

      test('All dashes fail (0 actual digits)', () {
        expect(AuthValidator.validatePhone('---'), '*enter valid number');
      });
    });

    group('capitalizeName', () {
      test('Capitalizes single word', () {
        expect(AuthValidator.capitalizeName('alice'), 'Alice');
      });

      test('Capitalizes multiple words', () {
        expect(AuthValidator.capitalizeName('john doe smith'), 'John Doe Smith');
      });

      test('Forces lowercase on remaining characters', () {
        expect(AuthValidator.capitalizeName('jOHN dOE'), 'John Doe');
      });

      test('Handles leading/trailing spaces', () {
        expect(AuthValidator.capitalizeName('  alice  '), 'Alice');
      });

      test('Empty string returns unchanged', () {
        expect(AuthValidator.capitalizeName(''), '');
      });

      test('All uppercase becomes properly capitalized', () {
        expect(AuthValidator.capitalizeName('ALICE BOB'), 'Alice Bob');
      });
    });
  });
}
