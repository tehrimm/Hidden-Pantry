import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

void main() {
  group('Integration: Parse steps fallback', () {
    test('Uses steps when directions missing', () {
      final r = Recipe.fromJson({
        'id': '2',
        'title': 'T2',
        'minutes': 6,
        'avg_rating': 3.1,
        'steps': ['a', 'b']
      });
      expect(r.directions.length, 2);
      expect(r.directions[0], 'a');
    });
  });
}

