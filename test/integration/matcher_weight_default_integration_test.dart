import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/utils/recipe_matcher.dart';

void main() {
  group('Integration: Matcher default weight', () {
    test('Unknown ingredient weight is 1.0', () {
      expect(RecipeMatcher.getWeight('kumquat'), 1.0);
    });
  });
}

