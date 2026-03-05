import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

void main() {
  group('Integration: Recipe total calories preference', () {
    test('Prefers nutrition Calories over sum of ingredients', () {
      final r = Recipe(
        id: 'r',
        name: 'R',
        minutes: 10,
        avgRating: 4.0,
        nutrition: {'Calories': '250 kcal'},
        ingredients: const [
          IngredientItem(name: 'a', quantity: 1, unit: '', calories: 100),
          IngredientItem(name: 'b', quantity: 1, unit: '', calories: 100),
        ],
        directions: const [],
      );
      expect(r.calculatedTotalCalories, 250.0);
    });
  });
}

