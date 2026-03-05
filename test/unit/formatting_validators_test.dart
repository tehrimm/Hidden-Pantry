import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/utils/auth_validator.dart';
import 'package:hidden_pantry_app/core/utils/string_utils.dart';

void main() {
  group('String Formatting & Validators Unit Tests', () {
    
    test('31. "+more" tag logic: Appends when exceeding limit', () {
      const text = "Chicken, Salt, Onion, Tomato, Pepper, Garlic";
      final result = StringUtils.truncateWithMore(text, 20);
      expect(result, "Chicken, Salt, Onion+more");
    });

    test('32. Time Formatting: Converts 90 minutes to 1h 30m', () {
      expect(StringUtils.formatTotalTime(90), "1h 30m");
    });

    test('33. Time Formatting: Converts 45 minutes to 45m', () {
      expect(StringUtils.formatTotalTime(45), "45m");
      expect(StringUtils.formatTotalTime(120), "2h");
    });

    test('34. Email Validator: Returns error for test@com', () {
      final result = AuthValidator.validateEmail("test@com");
      expect(result, "*incorrect email");
    });

    test('35. Email Validator: Valid for nutritionist@gmail.com', () {
      final result = AuthValidator.validateEmail("nutritionist@gmail.com");
      expect(result, isNull);
    });

    test('36. Password Validator: Returns error if under 8 characters', () {
      final result = AuthValidator.validatePassword("1234567");
      expect(result, "*password must be at least 8 characters");
    });

    test('40. Name Capitalization: john doe -> John Doe', () {
      expect(AuthValidator.capitalizeName("john doe"), "John Doe");
      expect(AuthValidator.capitalizeName("   JANE SMITH   "), "Jane Smith");
      expect(AuthValidator.capitalizeName("a b c"), "A B C");
    });

    // Note: Cases 38 (Routing) and 39 (IBAN) are skipped as "dead code" 
    // since bank detail functionality was previously removed from this project.
  });
}
