import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/utils/auth_validator.dart';

void main() {
  group('Integration: AuthValidator name and phone', () {
    test('Full name validation and capitalization', () {
      expect(AuthValidator.validateFullName(''), "*field is required");
      expect(AuthValidator.validateFullName('ab'), "*invalid name");
      expect(AuthValidator.validateFullName('john3'), "*invalid name");
      expect(AuthValidator.validateFullName('John Doe'), null);
      expect(AuthValidator.capitalizeName('jane DOE'), 'Jane Doe');
    });
    test('Phone number validation', () {
      expect(AuthValidator.validatePhone(''), "*phone number is required");
      expect(AuthValidator.validatePhone('12345'), "*enter valid number");
      expect(AuthValidator.validatePhone('+1 (650) 555-0000'), null);
    });
  });
}

