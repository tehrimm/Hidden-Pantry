import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/utils/recipe_matcher.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

void main() {
  group('Integration: Allergy exclusion in RecipeMatcher', () {
    test('Returns 0 match when allergen present, even if pantry matches', () {
      final recipe = Recipe(
        id: 'r1',
        name: 'Peanut Stir Fry',
        minutes: 25,
        avgRating: 4.6,
        ingredients: const [
          IngredientItem(name: 'peanuts', quantity: 50, unit: 'g'),
          IngredientItem(name: 'garlic', quantity: 2, unit: 'clove'),
        ],
        directions: const [],
      );
      final pantry = ['Peanuts', 'Garlic'];
      final allergies = ['Peanuts'];
      final m = RecipeMatcher.calculateMatch(recipe, pantry, allergies: allergies);
      expect(m, 0.0);
    });
  });
}

