import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

void main() {
  group('Integration: Recipe toJson shape', () {
    test('Includes core fields', () {
      final r = Recipe(
        id: 'x',
        name: 'X',
        minutes: 5,
        avgRating: 3.2,
        ingredients: const [IngredientItem(name: 'salt', quantity: 1, unit: 'g')],
        directions: const ['do'],
      );
      final j = r.toJson();
      expect(j.containsKey('id'), true);
      expect(j.containsKey('name'), true);
      expect((j['ingredients'] as List).length, 1);
      expect((j['directions'] as List).length, 1);
    });
  });
}

