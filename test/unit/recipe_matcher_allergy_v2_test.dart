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
    test('[Unit][RecipeMatcher][Allergy] egg filters variants like fresh egg', () {
      final recipe = r('r3', ['fresh egg', 'flour']);
      final score = RecipeMatcher.calculateMatch(recipe, ['flour'], allergies: ['egg']);
      expect(score, 0.0);
    });
    test('[Unit][RecipeMatcher][Allergy] tomatoes filter ketchup/marinara', () {
      final r1 = r('r4', ['ketchup', 'salt']);
      final r2 = r('r5', ['marinara sauce', 'pasta']);
      expect(RecipeMatcher.calculateMatch(r1, ['salt'], allergies: ['tomatoes']), 0.0);
      expect(RecipeMatcher.calculateMatch(r2, ['pasta'], allergies: ['tomato']), 0.0);
    });
    test('[Unit][RecipeMatcher][Allergy] caffeine filters coffee/tea', () {
      final r1 = r('r6', ['coffee', 'milk']);
      final r2 = r('r7', ['green tea', 'honey']);
      expect(RecipeMatcher.calculateMatch(r1, ['milk'], allergies: ['caffeine']), 0.0);
      expect(RecipeMatcher.calculateMatch(r2, ['honey'], allergies: ['caffeine']), 0.0);
    });
    test('[Unit][RecipeMatcher][Allergy] spicy filters chili powder', () {
      final r1 = r('r8', ['chili powder', 'salt']);
      expect(RecipeMatcher.calculateMatch(r1, ['salt'], allergies: ['spicy']), 0.0);
    });
  });
}
