import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/utils/recipe_matcher.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

Recipe rr(String id, List<String> ings, double rating, int minutes) {
  return Recipe(
    id: id,
    name: id,
    minutes: minutes,
    avgRating: rating,
    ingredients: ings.map((n) => IngredientItem(name: n, quantity: 1, unit: '')).toList(),
    directions: const [],
  );
}

void main() {
  group('Integration: Matcher weighting effect', () {
    test('Higher rarity ingredient yields higher score', () {
      final a = rr('a', ['saffron', 'water'], 4.0, 10);
      final b = rr('b', ['salt', 'water'], 4.0, 10);
      final pantry = ['saffron', 'salt'];
      final sa = RecipeMatcher.calculateMatch(a, pantry);
      final sb = RecipeMatcher.calculateMatch(b, pantry);
      expect(sa > sb, true);
    });
  });
}

