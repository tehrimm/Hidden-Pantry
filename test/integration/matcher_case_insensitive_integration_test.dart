import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/utils/recipe_matcher.dart';

void main() {
  group('Integration: Matcher case-insensitive', () {
    test('Case-insensitive matching', () {
      final ok = RecipeMatcher.isMatch('Garlic', ['garlic']);
      expect(ok, true);
    });
  });
}

