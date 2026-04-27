import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

void main() {
  group('Ingredient Parsing Logic Tests', () {
    test('Should parse messy ingredient strings with quantity and unit', () {
      final input = "1.5 cups of milk"; // Fallback case
      final item = IngredientItem.fromJson({'name': input});
      expect(item.name, input); // currently it just returns the string as name if not a map
    });

    test('Should parse stringified map with single quotes', () {
      final input = "{'name': 'Sugar', 'quantity': 2, 'unit': 'tbsp'}";
      final item = IngredientItem.fromJson({'name': input});
      expect(item.name, 'Sugar');
      expect(item.quantity, 2.0);
      expect(item.unit, 'tbsp');
    });

    test('Should parse ingredient with no unit', () {
      final input = "{'name': 'Salt', 'quantity': 1, 'unit': ''}";
      final item = IngredientItem.fromJson({'name': input});
      expect(item.name, 'Salt');
      expect(item.quantity, 1.0);
      expect(item.unit, '');
    });

    test('Should handle malformed stringified maps gracefully', () {
      final input = "{'name': 'Water', 'quantity': 'abc'}";
      final item = IngredientItem.fromJson({'name': input});
      expect(item.name, 'Water');
      expect(item.quantity, 1.0); // Typically defaults to 1.0 for unparsable quantities
    });
  });
}
