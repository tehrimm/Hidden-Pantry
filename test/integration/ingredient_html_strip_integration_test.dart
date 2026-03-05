import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

void main() {
  group('Integration: Ingredient HTML stripping', () {
    test('Strips tags from name and unit', () {
      final i = IngredientItem.fromJson({'name': '<b>garlic</b>', 'quantity': 1, 'unit': '<i>g</i>'});
      expect(i.name, 'garlic');
      expect(i.unit, 'g');
    });
  });
}

