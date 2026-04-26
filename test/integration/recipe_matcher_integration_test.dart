import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/utils/recipe_matcher.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

void main() {
  group('Real Integration Tests: RecipeMatcher End-to-End Ranking', () {
    // Build a realistic pool of recipes
    const chickenPasta = Recipe(
      id: 'r1',
      name: 'Chicken Pasta',
      minutes: 20,
      avgRating: 4.5,
      ingredients: [
        IngredientItem(name: 'chicken', quantity: 1, unit: 'breast'), // weight 1.5
        IngredientItem(name: 'pasta', quantity: 200, unit: 'g'),      // weight 0.5
        IngredientItem(name: 'garlic', quantity: 3, unit: 'cloves'),  // weight 0.8
      ],
    );

    const salmonDish = Recipe(
      id: 'r2',
      name: 'Salmon Fillet',
      minutes: 25,
      avgRating: 4.8,
      ingredients: [
        IngredientItem(name: 'salmon', quantity: 1, unit: 'fillet'), // weight 2.0 (rare!)
        IngredientItem(name: 'garlic', quantity: 2, unit: 'cloves'), // weight 0.8
      ],
    );

    const peanutDish = Recipe(
      id: 'r3',
      name: 'Peanut Noodles',
      minutes: 15,
      avgRating: 4.0,
      ingredients: [
        IngredientItem(name: 'peanut butter', quantity: 3, unit: 'tbsp'), // weight 1.0
        IngredientItem(name: 'noodles', quantity: 200, unit: 'g'),        // weight 1.0
      ],
    );

    test('sortRecipesByMatch ranks fully matched recipe highest', () {
      // Pantry has chicken + pasta + garlic → chickenPasta is 100% matched
      // Pantry has garlic only for salmon → partial match
      final pantry = ['chicken', 'pasta', 'garlic'];
      final sorted = RecipeMatcher.sortRecipesByMatch(
        [salmonDish, chickenPasta, peanutDish],
        pantry,
      );
      expect(sorted.first.id, 'r1'); // chickenPasta should be ranked first
    });

    test('sortRecipesByMatch excludes allergen recipes from top', () {
      // User is allergic to peanut. peanutDish should score 0.
      final pantry = ['peanut butter', 'noodles', 'chicken', 'pasta', 'garlic'];
      final sorted = RecipeMatcher.sortRecipesByMatch(
        [peanutDish, chickenPasta, salmonDish],
        pantry,
        allergies: ['peanut'],
      );
      // peanutDish gets 0.0, so it should not be first
      expect(sorted.first.id, isNot('r3'));
    });

    test('Rare ingredient (salmon) boosts score vs common ingredients', () {
      // Pantry has salmon + garlic (all of salmonDish's ingredients)
      // 100% match. Weight: salmon=2.0, garlic=0.8. Total=2.8, matched=2.8 → score=1.0
      final score = RecipeMatcher.calculateMatch(salmonDish, ['salmon', 'garlic']);
      expect(score, closeTo(1.0, 0.001));
    });

    test('Partial pantry gives partial weighted score', () {
      // Pantry has only chicken for chickenPasta
      // chicken weight=1.5, pasta weight=0.5, garlic weight=0.8. Total=2.8
      // matched=1.5, score = 1.5/2.8 ≈ 0.536
      final score = RecipeMatcher.calculateMatch(chickenPasta, ['chicken']);
      expect(score, closeTo(0.536, 0.01));
    });

    test('Empty pantry returns 0 for all recipes', () {
      for (final recipe in [chickenPasta, salmonDish, peanutDish]) {
        expect(RecipeMatcher.calculateMatch(recipe, []), 0.0);
      }
    });

    test('normalize handles plurals correctly', () {
      expect(RecipeMatcher.normalize('Eggs'), 'egg');     // strips 's'
      expect(RecipeMatcher.normalize('Tomatoes'), 'tomato'); // strips 'es'
      expect(RecipeMatcher.normalize('Chicken'), 'chicken');
      expect(RecipeMatcher.normalize('  FLOUR  '), 'flour');
    });

    test('getWeight returns known weights correctly', () {
      expect(RecipeMatcher.getWeight('chicken'), 1.5);
      expect(RecipeMatcher.getWeight('salmon'), 2.0);
      expect(RecipeMatcher.getWeight('saffron'), 3.0);
      expect(RecipeMatcher.getWeight('salt'), 0.1);
    });

    test('getWeight returns 1.0 default for unknown ingredient', () {
      expect(RecipeMatcher.getWeight('dragon fruit'), 1.0);
      expect(RecipeMatcher.getWeight('xyz_ingredient'), 1.0);
    });

    test('isMatch works case-insensitively', () {
      expect(RecipeMatcher.isMatch('Chicken', ['chicken', 'garlic']), true);
      expect(RecipeMatcher.isMatch('SALMON', ['salmon']), true);
      expect(RecipeMatcher.isMatch('beef', ['pork', 'chicken']), false);
    });
  });
}
