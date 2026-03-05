import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

void main() {
  group('Recipe Utility Logic Tests', () {
    test('Prep and Cook time calculation', () {
      final recipe = Recipe(
        id: '1',
        name: 'Test',
        minutes: 45,
        avgRating: 5.0,
      );
      
      // Default logic: if minutes >= 20, prep is 15, cook is minutes - 15
      expect(recipe.prepMinutes, 15);
      expect(recipe.cookMinutes, 30);
    });

    test('Short recipe time calculation', () {
      final recipe = Recipe(
        id: '2',
        name: 'Quick',
        minutes: 10,
        avgRating: 5.0,
      );
      expect(recipe.prepMinutes, 10);
      expect(recipe.cookMinutes, 0);
    });
  });
}
