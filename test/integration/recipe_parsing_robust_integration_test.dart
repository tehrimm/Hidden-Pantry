import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

void main() {
  group('Integration: Robust Recipe.fromJson parsing', () {
    test('Parses serving size strings and top-level nutrition', () {
      final r = Recipe.fromJson({
        'id': '10',
        'title': 'Test',
        'minutes': 40,
        'avg_rating': 4.2,
        'servings': '16 servings',
        'calories': '320 kcal',
        'protein': '10 g',
        'carbs': 45,
        'total_fat': '12 g',
        'sat_fat': '3 g',
        'sugar': '8 g',
        'sodium': '240 mg',
        'ingredients': [
          "{name: 'sugar', quantity: 1/2, unit: g}",
          "{name: flour, quantit: 100, unit: g}",
        ],
        'directions': 'Step 1\nStep 2'
      });
      expect(r.baseServings, 16);
      expect(r.nutrition?['Calories'], '320 kcal kcal');
      expect(r.nutrition?['Carbs'], '45 g');
      expect(r.ingredients.length, 2);
      expect(r.ingredients[0].name.toLowerCase(), 'sugar');
      expect(r.ingredients[0].quantity, 0.0);
      expect(r.ingredients[1].name.toLowerCase(), 'flour');
      expect(r.ingredients[1].quantity, 100.0);
      expect(r.directions.length, 2);
    });
  });
}
