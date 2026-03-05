import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

void main() {
  group('Integration: Recipe copyWith preserves', () {
    test('Preserves unspecified fields', () {
      final r = Recipe(
        id: 'a',
        name: 'A',
        minutes: 10,
        avgRating: 3.0,
        directions: const [],
        ingredients: const [],
      );
      final r2 = r.copyWith(avgRating: 4.5);
      expect(r2.id, 'a');
      expect(r2.name, 'A');
      expect(r2.avgRating, 4.5);
    });
  });
}

