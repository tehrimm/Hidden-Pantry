import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

void main() {
  group('Integration: Recipe serving multiplier edges', () {
    test('Handles base or target non-positive', () {
      final r1 = Recipe(id: '1', name: 'A', minutes: 10, avgRating: 4.0, baseServings: 0, directions: const [], ingredients: const []);
      final r2 = Recipe(id: '2', name: 'B', minutes: 10, avgRating: 4.0, baseServings: 2, directions: const [], ingredients: const []);
      expect(r1.getServingMultiplier(4), 1.0);
      expect(r2.getServingMultiplier(0), 1.0);
    });
  });
}

