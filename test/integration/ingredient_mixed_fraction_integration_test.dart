import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

void main() {
  group('Integration: Ingredient mixed fraction quantity', () {
    test('Parses 1 1/2 as 1.5', () {
      final i = IngredientItem.fromJson({'name': 'milk', 'quantity': '1 1/2', 'unit': 'cup'});
      expect(i.quantity, closeTo(1.5, 0.001));
    });
  });
}

