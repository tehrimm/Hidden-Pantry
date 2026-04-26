import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

void main() {
  group('Real Integration Tests: Recipe Scaling Pipeline (Parse → Scale → Output)', () {
    test('Full pipeline: parse from JSON then scale ingredients', () {
      // Simulates API response
      final json = {
        'id': 'pipeline_1',
        'name': 'Fluffy Pancakes',
        'minutes': 20,
        'avg_rating': 4.7,
        'base_servings': 2,
        'ingredients_parsed': [
          {'name': 'flour', 'quantity': '1 1/2', 'unit': 'cups'},  // 1.5 cups
          {'name': 'egg',   'quantity': '1',     'unit': 'pcs',  'calories': 70},
          {'name': 'milk',  'quantity': '1/2',   'unit': 'cup',  'calories': 50},
        ],
        'nutrition': {'Calories': '300 kcal', 'Protein': '8 g'},
      };

      final recipe = Recipe.fromJson(json);

      // Verify parsing
      expect(recipe.baseServings, 2);
      expect(recipe.ingredients.length, 3);
      expect(recipe.ingredients[0].name, 'flour');
      expect(recipe.ingredients[0].quantity, closeTo(1.5, 0.001));
      expect(recipe.ingredients[1].quantity, closeTo(1.0, 0.001));
      expect(recipe.ingredients[2].quantity, closeTo(0.5, 0.001));

      // Scale to 4 servings (multiplier = 2.0)
      final scaled = recipe.getScaledIngredients(4);
      expect(scaled[0].quantity, closeTo(3.0, 0.001));  // 1.5 * 2
      expect(scaled[1].quantity, closeTo(2.0, 0.001));  // 1 * 2
      expect(scaled[1].calories, closeTo(140.0, 0.001)); // 70 * 2
      expect(scaled[2].quantity, closeTo(1.0, 0.001));  // 0.5 * 2
      expect(scaled[2].calories, closeTo(100.0, 0.001)); // 50 * 2
    });

    test('Full pipeline: scale nutrition map to different serving sizes', () {
      final recipe = Recipe.fromJson({
        'id': 'p2',
        'name': 'Omelette',
        'minutes': 10,
        'avg_rating': 4.0,
        'base_servings': 1,
        'nutrition': {'Calories': '200 kcal', 'Protein': '14 g', 'Carbs': '2 g'},
        'ingredients_parsed': [],
      });

      // Scale to 3 servings
      final scaled = recipe.getScaledNutrition(3)!;
      expect(scaled['Calories'], contains('600'));  // 200 * 3
      expect(scaled['Protein'], contains('42'));    // 14 * 3
      expect(scaled['Carbs'], contains('6'));       // 2 * 3
    });

    test('Full pipeline: copyWith then re-scale preserves independence', () {
      const original = Recipe(
        id: 'p3', name: 'Soup', minutes: 30, avgRating: 3.5,
        baseServings: 4,
        ingredients: [
          IngredientItem(name: 'water', quantity: 4.0, unit: 'cups'),
        ],
      );

      // Modify via copyWith
      final modified = original.copyWith(id: 'p3_copy');

      // Scale both independently
      final origScaled = original.getScaledIngredients(8);  // multiply by 2
      final copyScaled = modified.getScaledIngredients(8);  // same multiplier

      expect(origScaled[0].quantity, closeTo(8.0, 0.001));
      expect(copyScaled[0].quantity, closeTo(8.0, 0.001));

      // Ensure they are independent objects
      expect(modified.id, 'p3_copy');
      expect(original.id, 'p3');
    });

    test('Full pipeline: calculatedTotalCalories uses nutrition map if present', () {
      final withNutrition = Recipe.fromJson({
        'id': 'p4', 'name': 'A', 'minutes': 10, 'avg_rating': 4.0,
        'nutrition': {'Calories': '500 kcal'},
        'ingredients_parsed': [
          {'name': 'sugar', 'quantity': 1, 'unit': 'cup', 'calories': 200},
        ],
      });
      // Nutrition map wins (500 > 200)
      expect(withNutrition.calculatedTotalCalories, closeTo(500.0, 0.01));
    });

    test('Full pipeline: calculatedTotalCalories falls back to ingredients sum', () {
      final noNutrition = Recipe(
        id: 'p5', name: 'B', minutes: 10, avgRating: 4.0,
        ingredients: const [
          IngredientItem(name: 'apple', quantity: 1, unit: 'pcs', calories: 95),
          IngredientItem(name: 'banana', quantity: 1, unit: 'pcs', calories: 89),
        ],
      );
      // No nutrition map → sums ingredients: 95 + 89 = 184
      expect(noNutrition.calculatedTotalCalories, closeTo(184.0, 0.01));
    });

    test('Full pipeline: getNutrient uses alias matching across cases', () {
      final recipe = Recipe.fromJson({
        'id': 'p6', 'name': 'C', 'minutes': 10, 'avg_rating': 4.0,
        'nutrition': {
          'Total Fat': '12 g',
          'Carbohydrates': '45 g',
          'Sodium': '220 mg',
        },
      });
      // Should find via alias 'fats' → 'total fat'
      expect(recipe.getNutrient('fats'), '12 g');
      // Should find via alias 'carbs' → 'carbohydrates'
      expect(recipe.getNutrient('carbs'), '45 g');
      // Direct match
      expect(recipe.getNutrient('Sodium'), '220 mg');
      // Unknown → '0g'
      expect(recipe.getNutrient('iron'), '0g');
    });
  });
}
