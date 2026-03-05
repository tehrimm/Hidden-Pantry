import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

void main() {
  group('Integration: Directions bullet split', () {
    test('Splits single string with bullets into steps', () {
      final r = Recipe.fromJson({
        'id': '1',
        'title': 'T',
        'minutes': 5,
        'avg_rating': 3.0,
        'directions': '- Step 1\n- Step 2'
      });
      expect(r.directions.length, 2);
    });
  });
}

