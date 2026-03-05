import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/utils/recipe_matcher.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

Recipe r(String id, int minutes) {
  return Recipe(
    id: id,
    name: id,
    minutes: minutes,
    avgRating: 4.0,
    ingredients: const [IngredientItem(name: 'salt', quantity: 1, unit: '')],
    directions: const [],
  );
}

void main() {
  group('Integration: Matcher minutes tiebreak', () {
    test('Shorter minutes first when match and rating equal', () {
      final a = r('a', 20);
      final b = r('b', 10);
      final sorted = RecipeMatcher.sortRecipesByMatch([a, b], const ['salt']);
      expect(sorted.first.id, 'b');
      expect(sorted.last.id, 'a');
    });
  });
}

