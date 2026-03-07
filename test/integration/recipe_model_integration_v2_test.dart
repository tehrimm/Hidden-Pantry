import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

void main() {
  group('[Integration][Recipe][Model]', () {
    test('[Integration] fromJson common variants', () {
      final r1 = Recipe.fromJson({
        'id': 'x1',
        'name': 'X',
        'minutes': 25,
        'avg_rating': 4.2,
        'ingredients': [
          {'name': 'salt', 'quantity': 1, 'unit': 'tsp'}
        ],
        'tags': ['tag'],
      });
      expect(r1.id, 'x1');
      expect(r1.minutes, 25);
      expect(r1.avgRating >= 0, true);

      final r2 = Recipe.fromJson({
        '_id': 'x2',
        'title': 'Y',
        'minutes': '15',
        'avgRating': '3.5',
        'ingredients': [
          {'name': 'water', 'quantity': '2', 'unit': 'cup'}
        ],
      });
      expect(r2.id.isNotEmpty, true);
      expect(r2.name.isNotEmpty, true);
    });
  });
}

