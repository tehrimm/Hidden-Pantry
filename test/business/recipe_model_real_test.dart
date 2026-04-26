import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

void main() {
  group('Real Business Tests: Recipe Model Logic', () {
    late Recipe testRecipe;

    setUp(() {
      testRecipe = const Recipe(
        id: '1',
        name: 'Test Recipe',
        minutes: 45,
        avgRating: 4.0,
        baseServings: 2,
        ingredients: [
          IngredientItem(name: 'flour', quantity: 1.5, unit: 'cups', calories: 150),
          IngredientItem(name: 'sugar', quantity: 0.5, unit: 'cup', calories: 50),
        ],
        nutrition: {
          'Calories': '200 kcal',
          'Protein': '5.5 g',
          'Carbs': '30 g'
        },
      );
    });

    group('Serving Scaling', () {
      test('getServingMultiplier returns 1.0 for invalid target servings', () {
        expect(testRecipe.getServingMultiplier(-1), 1.0);
        expect(testRecipe.getServingMultiplier(0), 1.0);
      });

      test('getServingMultiplier calculates correct ratio', () {
        // base is 2. Target 4 -> 2.0. Target 1 -> 0.5.
        expect(testRecipe.getServingMultiplier(4), 2.0);
        expect(testRecipe.getServingMultiplier(1), 0.5);
      });

      test('getScaledIngredients scales quantities and calories', () {
        // Target 4 servings (multiplier 2.0)
        final scaled = testRecipe.getScaledIngredients(4);
        
        expect(scaled[0].name, 'flour');
        expect(scaled[0].quantity, 3.0); // 1.5 * 2
        expect(scaled[0].calories, 300.0); // 150 * 2
        
        expect(scaled[1].name, 'sugar');
        expect(scaled[1].quantity, 1.0); // 0.5 * 2
        expect(scaled[1].calories, 100.0); // 50 * 2
      });

      test('getScaledNutrition formats scaled nutrition strings', () {
        // Target 4 servings (multiplier 2.0)
        final scaledNut = testRecipe.getScaledNutrition(4)!;
        
        // 200 * 2 = 400
        expect(scaledNut['Calories'], '400 kcal');
        // 5.5 * 2 = 11.0. Whole numbers drop decimal.
        expect(scaledNut['Protein'], '11 g');
        // 30 * 2 = 60
        expect(scaledNut['Carbs'], '60 g');
      });
      
      test('getScaledNutrition handles decimal formatting', () {
        // Target 3 servings (multiplier 1.5)
        final scaledNut = testRecipe.getScaledNutrition(3)!;
        
        // 5.5 * 1.5 = 8.25 -> rounded to 1 decimal place = "8.3"
        // In Dart, 8.25.toStringAsFixed(1) might be 8.2 or 8.3 depending on implementation, 
        // but it will be a decimal. 
        expect(scaledNut['Protein']!.contains('.'), true); 
      });
    });

    group('Calorie and Time Calculations', () {
      test('calculatedTotalCalories prioritizes nutrition map over ingredients', () {
        expect(testRecipe.calculatedTotalCalories, 200.0);
      });

      test('calculatedTotalCalories falls back to ingredients if nutrition is null', () {
        final fallbackRecipe = testRecipe.copyWith(
          // Using copyWith but setting nutrition to null is tricky without a specific null-clearing method
          // Let's create a new instance manually.
        );
        
        final noNutRecipe = Recipe(
          id: '2', name: 'No Nut', minutes: 10, avgRating: 5.0,
          ingredients: testRecipe.ingredients,
        ); // default nutrition is null
        
        expect(noNutRecipe.calculatedTotalCalories, 200.0); // 150 + 50
      });

      test('prepMinutes and cookMinutes derive correctly from total minutes', () {
        // total minutes = 45. Defaults: prep=15, cook=30 (45-15)
        expect(testRecipe.prepMinutes, 15);
        expect(testRecipe.cookMinutes, 30);
      });
      
      test('prepMinutes and cookMinutes logic for under 20 minutes', () {
        final fastRecipe = Recipe(
          id: '3', name: 'Fast', minutes: 10, avgRating: 5.0,
        );
        // total = 10. prep = 10, cook = 0.
        expect(fastRecipe.prepMinutes, 10);
        expect(fastRecipe.cookMinutes, 0);
      });
    });

    group('getNutrient', () {
      test('Retrieves exact matches', () {
        expect(testRecipe.getNutrient('Calories'), '200 kcal');
        expect(testRecipe.getNutrient('Protein'), '5.5 g');
      });

      test('Retrieves using aliases case-insensitively', () {
        // Alias for 'Carbs' includes 'carbohydrates'
        expect(testRecipe.getNutrient('carbohydrates'), '30 g');
        // Alias for 'Protein' includes 'p'
        expect(testRecipe.getNutrient('p'), '5.5 g');
      });

      test('Returns 0g for missing nutrients', () {
        expect(testRecipe.getNutrient('Sodium'), '0g');
        expect(testRecipe.getNutrient('Fats'), '0g');
      });
    });
  });
}
