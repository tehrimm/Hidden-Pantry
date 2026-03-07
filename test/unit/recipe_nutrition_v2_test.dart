import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

void main() {
  group('[Unit][Recipe][Nutrition]', () {
    test('[Unit][Recipe][Nutrition] calculatedTotalCalories uses nutrition map if present', () {
      final r = Recipe(
        id: 'r1',
        name: 'R1',
        minutes: 10,
        avgRating: 4.0,
        ingredients: [
          IngredientItem(name: 'salt', quantity: 1, unit: '', calories: 5),
        ],
        directions: const [],
        nutrition: {'Calories': '123 kcal'},
      );
      expect(r.calculatedTotalCalories, 123);
    });

    test('[Unit][Recipe][Nutrition] calculatedTotalCalories sums ingredients if no nutrition', () {
      final r = Recipe(
        id: 'r2',
        name: 'R2',
        minutes: 10,
        avgRating: 4.0,
        ingredients: [
          IngredientItem(name: 'a', quantity: 1, unit: '', calories: 10),
          IngredientItem(name: 'b', quantity: 1, unit: '', calories: 15),
        ],
        directions: const [],
      );
      expect(r.calculatedTotalCalories, 25);
    });

    test('[Unit][Recipe][Nutrition] scaled nutrition applies serving multiplier', () {
      final r = Recipe(
        id: 'r3',
        name: 'R3',
        minutes: 10,
        avgRating: 4.0,
        baseServings: 2,
        directions: const [],
        nutrition: {'Calories': '200 kcal', 'Protein': '10 g'},
      );
      final scaled = r.getScaledNutrition(4);
      expect(scaled?['Calories']?.contains('400'), true);
      expect(scaled?['Protein']?.contains('20'), true);
    });
  });
}

