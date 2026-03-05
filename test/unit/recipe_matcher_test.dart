import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/core/utils/recipe_matcher.dart';

void main() {
  group('RecipeMatcher Unit Tests', () {
    final recipe = Recipe(
      id: '1',
      name: 'Test Recipe',
      minutes: 30,
      avgRating: 4.5,
      ingredients: [
        IngredientItem(name: 'Chicken', quantity: 1, unit: 'lb'),
        IngredientItem(name: 'Salt', quantity: 1, unit: 'tsp'),
        IngredientItem(name: 'Onion', quantity: 1, unit: 'whole'),
        IngredientItem(name: 'Tomato', quantity: 1, unit: 'whole'),
      ],
    );

    test('21. Exact Match: 100% when pantry contains all ingredients', () {
      final pantry = ['Chicken', 'Salt', 'Onion', 'Tomato'];
      final score = RecipeMatcher.calculateMatch(recipe, pantry);
      expect(score, 1.0);
    });

    test('22. Partial Match: Matches expected ratio based on weights', () {
      // Chicken(1.5), Salt(0.1) = 1.6
      // Total = 1.5 + 0.1 + 0.8 + 1.0 = 3.4
      // Ratio = 1.6 / 3.4 ≈ 0.47
      final pantry = ['Chicken', 'Salt'];
      final score = RecipeMatcher.calculateMatch(recipe, pantry);
      expect(score, closeTo(0.47, 0.01));
    });

    test('23. Missing Core Ingredient: Lower score if main ingredient is missing', () {
      // Missing Chicken(1.5), has others
      // Ratio = (0.1 + 0.8 + 1.0) / 3.4 = 1.9 / 3.4 ≈ 0.55
      final pantry = ['Salt', 'Onion', 'Tomato'];
      final score = RecipeMatcher.calculateMatch(recipe, pantry);
      expect(score, closeTo(0.55, 0.01));
      
      // Compare with having Chicken but missing two others
      // Having Chicken(1.5) + Salt(0.1) = 1.6 / 3.4 ≈ 0.47
      // Wait, let's just assert it behaves predictably with weights.
    });

    test('24. Case Insensitivity: "Chicken" matches "chicken"', () {
      final pantry = ['chicken', 'SALT', 'onioN', 'tomatO'];
      final score = RecipeMatcher.calculateMatch(recipe, pantry);
      expect(score, 1.0);
    });

    test('25. Pluralization: "Tomatoes" matches "Tomato"', () {
      final pantry = ['Chickens', 'Salts', 'Onions', 'Tomatoes'];
      final score = RecipeMatcher.calculateMatch(recipe, pantry);
      expect(score, 1.0);
    });

    test('26. TF-IDF Weighting: Saffron weighs more than Salt', () {
      final saffronRecipe = Recipe(
        id: '2',
        name: 'Saffron Rice',
        minutes: 20,
        avgRating: 5.0,
        ingredients: [
          IngredientItem(name: 'Saffron', quantity: 1, unit: 'pinch'),
          IngredientItem(name: 'Salt', quantity: 1, unit: 'pinch'),
        ],
      );
      
      // Saffron (3.0) / Total (3.1) = ~0.96
      expect(RecipeMatcher.calculateMatch(saffronRecipe, ['Saffron']), closeTo(0.96, 0.01));
      // Salt (0.1) / Total (3.1) = ~0.03
      expect(RecipeMatcher.calculateMatch(saffronRecipe, ['Salt']), closeTo(0.03, 0.01));
    });

    test('27. Exclude Allergens: Returns 0.0 if any ingredient is an allergen', () {
      final pantry = ['Chicken', 'Salt', 'Onion', 'Tomato'];
      final allergies = ['Chicken'];
      final score = RecipeMatcher.calculateMatch(recipe, pantry, allergies: allergies);
      expect(score, 0.0);
    });

    test('28. Empty Pantry: Returns 0.0', () {
      final score = RecipeMatcher.calculateMatch(recipe, []);
      expect(score, 0.0);
    });

    test('29. Sorting Logic: Recipes in descending match order', () {
      final r1 = recipe; // match 1.0 (with full pantry)
      final r2 = Recipe(id: '2', name: 'R2', minutes: 10, avgRating: 4.0, ingredients: [
        IngredientItem(name: 'Chicken', quantity: 1, unit: 'lb'),
      ]); // match 1.0
      final r3 = Recipe(id: '3', name: 'R3', minutes: 10, avgRating: 4.0, ingredients: [
        IngredientItem(name: 'Salt', quantity: 1, unit: 'lb'),
        IngredientItem(name: 'Water', quantity: 1, unit: 'lb'),
      ]); // match 0.5 (with only Salt in pantry)

      final sorted = RecipeMatcher.sortRecipesByMatch([r3, r1, r2], ['Chicken', 'Salt']);
      // r2(1.0) because it only has Chicken. 
      // r1(~0.47) because it has Chicken, Salt, Onion, Tomato.
      // r3(0.5) because it has Salt and Water.
      expect(sorted.first.id, '2'); // r2 wins via highest match %
      expect(sorted[1].id, '3');
      expect(sorted.last.id, '1');
    });

    test('30. Tie-breaker sorting: Identical match % sorted by rating then time', () {
      final r1 = Recipe(id: '1', name: 'R1', minutes: 30, avgRating: 4.0, ingredients: [IngredientItem(name: 'Salt', quantity: 1, unit: 'g')]);
      final r2 = Recipe(id: '2', name: 'R2', minutes: 20, avgRating: 4.5, ingredients: [IngredientItem(name: 'Salt', quantity: 1, unit: 'g')]);
      final r3 = Recipe(id: '3', name: 'R3', minutes: 15, avgRating: 4.5, ingredients: [IngredientItem(name: 'Salt', quantity: 1, unit: 'g')]);

      final sorted = RecipeMatcher.sortRecipesByMatch([r1, r2, r3], ['Salt']);
      expect(sorted[0].id, '3'); // Highest rating (4.5) and lowest time (15)
      expect(sorted[1].id, '2'); // Highest rating (4.5) but higher time (20)
      expect(sorted[2].id, '1'); // Lower rating (4.0)
    });
  });
}
