import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

void main() {
  group('Integration: Ingredient simple fraction quantity', () {
    test('Parses 1/2 as 0.5', () {
      final i = IngredientItem.fromJson({'name': 'butter', 'quantity': '1/2', 'unit': 'tbsp'});
      expect(i.quantity, closeTo(0.5, 0.001));
    });
  });
}

