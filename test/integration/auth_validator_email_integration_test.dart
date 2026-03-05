import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/utils/auth_validator.dart';

void main() {
  group('Integration: AuthValidator email', () {
    test('Detects empty and malformed', () {
      expect(AuthValidator.validateEmail(''), "*email field is required");
      expect(AuthValidator.validateEmail('foo'), "*incorrect email");
      expect(AuthValidator.validateEmail('foo@bar'), "*incorrect email");
      expect(AuthValidator.validateEmail('foo@bar.com'), null);
    });
  });
}

