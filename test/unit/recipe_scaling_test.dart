import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

void main() {
  group('Recipe Scaling & Math Tests', () {
    final baseRecipe = Recipe(
      id: 'r1',
      name: 'Test Recipe',
      minutes: 30,
      avgRating: 4.5,
      baseServings: 2,
      ingredients: [
        IngredientItem(name: 'Milk', quantity: 0.5, unit: 'cup', calories: 100),
        IngredientItem(name: 'Flour', quantity: 100.0, unit: 'g', calories: 360),
      ],
      nutrition: {
        'Calories': '460 kcal',
        'Protein': '10 g',
        'Carbs': '50 g',
        'Total Fat': '5 g',
      },
    );

    test('11. Serving Multiplier: Base 2 servings scaled to 4 gives a modifier of 2.0', () {
      expect(baseRecipe.getServingMultiplier(4), 2.0);
    });

    test('12. Serving Multiplier: Base 4 servings scaled to 2 gives a modifier of 0.5', () {
      // Need a new Recipe instance with baseServings 4 since current baseRecipe is base 2
      final recipe4 = Recipe(
        id: 'r4',
        name: 'r4',
        minutes: 1,
        avgRating: 1,
        baseServings: 4,
      );
      expect(recipe4.getServingMultiplier(2), 0.5);
    });

    test('13. Ingredient Quantity: 100g scales to 200g when serving doubles', () {
      final scaled = baseRecipe.getScaledIngredients(4);
      final flour = scaled.firstWhere((i) => i.name == 'Flour');
      expect(flour.quantity, 200.0);
    });

    test('14. Macros: Calories scale exactly with the serving modifier', () {
      final scaledNutrition = baseRecipe.getScaledNutrition(4);
      expect(scaledNutrition?['Calories'], '920 kcal');
    });

    test('15. Macros: Protein, Carbs, and Fats scale exactly with the serving modifier', () {
      final scaledNutrition = baseRecipe.getScaledNutrition(4);
      expect(scaledNutrition?['Protein'], '20 g');
      expect(scaledNutrition?['Carbs'], '100 g');
      expect(scaledNutrition?['Total Fat'], '10 g');
    });

    test('16. Fraction Handling: 1/2 cup scales to 1 cup when doubled', () {
      final scaled = baseRecipe.getScaledIngredients(4);
      final milk = scaled.firstWhere((i) => i.name == 'Milk');
      expect(milk.quantity, 1.0);
      expect(milk.unit, 'cup');
    });

    test('18. Edge Case: Scaling serving size to 0 defaults to 1.0 multiplier', () {
      expect(baseRecipe.getServingMultiplier(0), 1.0);
    });

    test('19. Edge Case: Missing base serving size defaults to 1 for multiplier logic', () {
      final rNoBase = Recipe(
        id: 'rb',
        name: 'rb',
        minutes: 1,
        avgRating: 1,
        baseServings: 0, // 0 or negative should default to 1 in logic
      );
      expect(rNoBase.getServingMultiplier(2), 1.0); 
      // Based on my implementation: if (baseServings <= 0) return 1.0;
    });

    test('20. Total Recipe Calories: Correctly sums the calories of individual ingredients if total is missing', () {
      final rNoNutri = Recipe(
        id: 'rn',
        name: 'rn',
        minutes: 1,
        avgRating: 1,
        baseServings: 1,
        ingredients: [
          IngredientItem(name: 'A', quantity: 1, unit: 'x', calories: 150),
          IngredientItem(name: 'B', quantity: 1, unit: 'y', calories: 250),
        ],
      );
      expect(rNoNutri.calculatedTotalCalories, 400.0);
    });

    test('20b. Total Recipe Calories: Uses nutrition map value if available', () {
      expect(baseRecipe.calculatedTotalCalories, 460.0);
    });
  });
}
