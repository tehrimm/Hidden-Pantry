import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/utils/auth_validator.dart';

void main() {
  group('[Unit][AuthValidator][CapitalizeName]', () {
    final cases = {
      'john doe': 'John Doe',
      '  alice   smith  ': 'Alice   Smith',
      'McDonald': 'Mcdonald',
      'A.B.': 'A.b.',
      'o\'connor': 'O\'connor',
    };
    cases.forEach((input, output) {
      test('[Unit][AuthValidator][CapitalizeName] "$input" -> "$output"', () {
        expect(AuthValidator.capitalizeName(input), output);
      });
    });
  });
}
