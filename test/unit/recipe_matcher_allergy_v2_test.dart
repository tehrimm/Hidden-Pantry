import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/utils/recipe_matcher.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

Recipe r(String id, List<String> ings) => Recipe(
      id: id,
      name: id,
      minutes: 20,
      avgRating: 4.0,
      ingredients: ings.map((e) => IngredientItem(name: e, quantity: 1, unit: '')).toList(),
      directions: const [],
    );

void main() {
  group('[Unit][RecipeMatcher][Allergy]', () {
    test('[Unit][RecipeMatcher][Allergy] returns 0 when allergen present', () {
      final recipe = r('r1', ['chicken', 'salt', 'onion']);
      final score = RecipeMatcher.calculateMatch(recipe, ['chicken', 'salt', 'onion'], allergies: ['chicken']);
      expect(score, 0.0);
    });

    test('[Unit][RecipeMatcher][Allergy] positive score when no allergen', () {
      final recipe = r('r2', ['chicken', 'salt', 'onion']);
      final score = RecipeMatcher.calculateMatch(recipe, ['chicken', 'salt', 'onion']);
      expect(score > 0.0, true);
    });
  });
}

