import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/utils/auth_validator.dart';

void main() {
  group('Integration: AuthValidator password', () {
    test('Enforces minimum length', () {
      expect(AuthValidator.validatePassword(''), "*password field is required");
      expect(AuthValidator.validatePassword('short'), "*password must be at least 8 characters");
      expect(AuthValidator.validatePassword('abcdefgh'), null);
    });
  });
}

