import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/utils/recipe_matcher.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

Recipe r(String id, String name, double rating, int minutes, List<String> ings) {
  return Recipe(
    id: id,
    name: name,
    minutes: minutes,
    avgRating: rating,
    ingredients: ings.map((n) => IngredientItem(name: n, quantity: 1, unit: '')).toList(),
    directions: const [],
  );
}

void main() {
  group('Integration: RecipeMatcher tie-breakers and scoring', () {
    test('Sort by match desc, then rating desc, then minutes asc', () {
      final recipes = [
        r('a', 'A', 4.0, 30, ['chicken', 'onions', 'salt']),
        r('b', 'B', 4.8, 45, ['chicken', 'garlic', 'flour']),
        r('c', 'C', 4.8, 25, ['beef', 'garlic', 'salt']),
      ];
      final pantry = ['Chicken', 'Garlic', 'Salt'];
      final sorted = RecipeMatcher.sortRecipesByMatch(recipes, pantry);
      expect(sorted.first.id, 'b');
      expect(sorted[1].id, 'a');
      expect(sorted.last.id, 'c');
    });
  });
}
