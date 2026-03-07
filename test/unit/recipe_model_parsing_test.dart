import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

void main() {
  group('Recipe.fromJson parsing', () {
    test('parses top-level nutrition fields', () {
      final r = Recipe.fromJson({
        'id': '1',
        'title': 'Test Dish',
        'minutes': 30,
        'ingredients': ['salt', 'water'],
        'calories': 250,
        'protein': 10,
        'carbs': 30,
        'total_fat': 5,
        'sat_fat': 2,
        'sugar': 4,
        'sodium': 1000,
      });

      expect(r.name, 'Test Dish');
      expect(r.nutrition, isNotNull);
      expect(r.nutrition!['Calories'], contains('kcal'));
    });

    test('parses nested nutrition map', () {
      final r = Recipe.fromJson({
        'id': '2',
        'title': 'Nested',
        'minutes': 10,
        'ingredients': ['salt'],
        'nutrition': {
          'Calories': '120 kcal',
          'Protein': '5 g',
        },
      });
      expect(r.nutrition?['Calories'], '120 kcal');
      expect(r.nutrition?['Protein'], '5 g');
    });

    test('parses ingredients from strings and messy map strings', () {
      final r = Recipe.fromJson({
        'id': '3',
        'title': 'Messy',
        'minutes': 5,
        'ingredients': [
          'salt',
          "{name: tomato, quantity: 2, unit: pcs}",
        ],
      });
      expect(r.ingredients.length, 2);
      expect(r.ingredients.first.name.toLowerCase(), 'salt');
      expect(r.ingredients[1].name.toLowerCase(), 'tomato');
      expect(r.ingredients[1].quantity, 2);
      expect(r.ingredients[1].unit, 'pcs');
    });
  });

  group('Recipe scaling helpers', () {
    test('getServingMultiplier and getScaledIngredients', () {
      final r = Recipe(
        id: '10',
        name: 'Scale Me',
        minutes: 20,
        avgRating: 0.0,
        baseServings: 2,
        ingredients: const [
          IngredientItem(name: 'rice', quantity: 100, unit: 'g'),
          IngredientItem(name: 'salt', quantity: 1, unit: 'tsp'),
        ],
      );
      final mult = r.getServingMultiplier(4);
      expect(mult, 2.0);
      final scaled = r.getScaledIngredients(4);
      expect(scaled.first.quantity, 200);
      expect(scaled.last.quantity, 2);
    });

    test('getScaledNutrition and calculatedTotalCalories fallback', () {
      final r = Recipe(
        id: '11',
        name: 'Nutrition',
        minutes: 10,
        avgRating: 0.0,
        baseServings: 1,
        ingredients: const [
          IngredientItem(name: 'oil', quantity: 10, unit: 'ml', calories: 90),
        ],
        nutrition: const {'Calories': '120 kcal'},
      );
      // Direct calories
      expect(r.calculatedTotalCalories, 120);
      final scaled = r.getScaledNutrition(2)!;
      expect(scaled['Calories'], contains('240'));

      // Fallback when nutrition absent
      final r2 = Recipe(
        id: '12',
        name: 'NoNutri',
        minutes: 10,
        avgRating: 0.0,
        ingredients: const [
          IngredientItem(name: 'oil', quantity: 10, unit: 'ml', calories: 90),
          IngredientItem(name: 'butter', quantity: 10, unit: 'g', calories: 72),
        ],
      );
      expect(r2.calculatedTotalCalories, 162);
    });
  });
}

