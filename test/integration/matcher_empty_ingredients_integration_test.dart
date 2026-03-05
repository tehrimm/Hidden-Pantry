import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/utils/recipe_matcher.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

void main() {
  group('Integration: Matcher empty ingredients', () {
    test('Returns 0', () {
      final r = Recipe(id: 'r', name: 'R', minutes: 1, avgRating: 1.0, ingredients: const [], directions: const []);
      final m = RecipeMatcher.calculateMatch(r, const ['salt']);
      expect(m, 0.0);
    });
  });
}

