import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

void main() {
  group('Integration: Recipe nutrition and ingredient scaling', () {
    test('Scales ingredients and nutrition with rounding rules', () {
      final recipe = Recipe(
        id: 'r1',
        name: 'Pancakes',
        minutes: 20,
        avgRating: 4.5,
        baseServings: 2,
        nutrition: {
          'Calories': '200 kcal',
          'Protein': '5 g',
          'Sugar': '12.5 g',
        },
        ingredients: const [
          IngredientItem(name: 'flour', quantity: 100, unit: 'g'),
          IngredientItem(name: 'sugar', quantity: 10, unit: 'g'),
        ],
        directions: const [],
      );
      final scaledIngs = recipe.getScaledIngredients(3);
      expect(scaledIngs[0].quantity, 150.0);
      expect(scaledIngs[1].quantity, 15.0);
      final n = recipe.getScaledNutrition(3)!;
      expect(n['Calories'], '300 kcal');
      expect(n['Protein'], '7.5 g');
      expect(n['Sugar'], '18.8 g');
    });
  });
}
