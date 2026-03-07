import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

void main() {
  group('[Unit][Recipe.fromJson][Shapes]', () {
    final cases = [
      {
        'id': '1',
        'name': 'A',
        'minutes': 30,
        'avg_rating': 4.5,
        'ingredients': [
          {'name': 'salt', 'quantity': 1, 'unit': 'tsp'}
        ],
        'tags': ['test'],
      },
      {
        '_id': '2',
        'title': 'B',
        'minutes': '45',
        'avgRating': '4.0',
        'ingredients': [
          {'name': 'water', 'quantity': '2', 'unit': 'cup'}
        ],
        'tags': ['x', 'y'],
      },
      {
        'id': '3',
        'name': 'C',
        'minutes': 0,
        'avgRating': 0,
        'ingredients': [],
        'tags': [],
      },
      {
        'id': '4',
        'name': 'D',
        'minutes': '15',
        'avg_rating': '5',
        'ingredients': [
          {'name': 'sugar', 'quantity': 0.5, 'unit': 'cup'}
        ],
      },
      {
        'id': '5',
        'name': 'E',
        'minutes': 'not a number',
        'avgRating': 'not a number',
        'ingredients': [
          {'name': "['garlic']", 'quantity': '1', 'unit': 'clove'}
        ],
      },
    ];

    for (var i = 0; i < cases.length; i++) {
      final data = cases[i];
      test('[Unit][Recipe.fromJson][Shapes] case-$i', () {
        final r = Recipe.fromJson(data);
        expect(r.id.isNotEmpty, true);
        expect(r.name.isNotEmpty, true);
        expect(r.minutes >= 0, true);
        expect(r.avgRating >= 0, true);
      });
    }
  });
}

