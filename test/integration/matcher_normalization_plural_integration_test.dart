import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/utils/recipe_matcher.dart';

void main() {
  group('Integration: Matcher normalization plural handling', () {
    test('Matches plural to singular', () {
      final ok = RecipeMatcher.isMatch('onions', ['onion']);
      expect(ok, true);
    });
  });
}

