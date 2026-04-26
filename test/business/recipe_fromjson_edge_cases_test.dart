import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

void main() {
  group('Real Business Tests: Recipe.fromJson Edge Cases', () {
    test('fromJson handles completely empty map with safe defaults', () {
      final recipe = Recipe.fromJson({});
      expect(recipe.id, '');
      expect(recipe.name, '');
      expect(recipe.minutes, 0);
      expect(recipe.avgRating, 0.0);
      expect(recipe.ingredients, isEmpty);
      expect(recipe.directions, isEmpty);
      expect(recipe.allergens, isEmpty);
      expect(recipe.tags, isEmpty);
    });

    test('fromJson reads alternate id field names', () {
      final r1 = Recipe.fromJson({'recipe_id': 'alt_1', 'name': 'Test'});
      expect(r1.id, 'alt_1');

      final r2 = Recipe.fromJson({'recipeId': 'alt_2', 'name': 'Test'});
      expect(r2.id, 'alt_2');

      final r3 = Recipe.fromJson({'_id': 'alt_3', 'name': 'Test'});
      expect(r3.id, 'alt_3');
    });

    test('fromJson reads alternate name field names', () {
      final r1 = Recipe.fromJson({'id': '1', 'title': 'From Title'});
      expect(r1.name, 'From Title');

      final r2 = Recipe.fromJson({'id': '2', 'recipe_name': 'From recipe_name'});
      expect(r2.name, 'From recipe_name');
    });

    test('fromJson reads alternate rating field names', () {
      final r1 = Recipe.fromJson({'id': '1', 'name': 'A', 'avg_rating': 4.5});
      expect(r1.avgRating, 4.5);

      final r2 = Recipe.fromJson({'id': '2', 'name': 'B', 'rating': 3.8});
      expect(r2.avgRating, 3.8);
    });

    test('fromJson reads alternate time field names', () {
      final r1 = Recipe.fromJson({'id': '1', 'name': 'A', 'readyInMinutes': 45});
      expect(r1.minutes, 45);

      final r2 = Recipe.fromJson({'id': '2', 'name': 'B', 'total_time': 60});
      expect(r2.minutes, 60);
    });

    test('fromJson reads alternate image field names', () {
      final r1 = Recipe.fromJson({'id': '1', 'name': 'A', 'imageUrl': 'http://img.com/1.jpg'});
      expect(r1.imageUrl, 'http://img.com/1.jpg');

      final r2 = Recipe.fromJson({'id': '2', 'name': 'B', 'image_url': 'http://img.com/2.jpg'});
      expect(r2.imageUrl, 'http://img.com/2.jpg');
    });

    test('fromJson handles numeric string for minutes', () {
      // e.g., some APIs return "45" as a string
      final recipe = Recipe.fromJson({'id': '1', 'name': 'A', 'minutes': '45'});
      expect(recipe.minutes, 45);
    });

    test('fromJson strips null-like strings from nullable fields', () {
      final recipe = Recipe.fromJson({
        'id': '1',
        'name': 'A',
        'description': 'null', // string "null"
        'category': '',        // empty string
      });
      expect(recipe.description, null); // should be null, not "null"
      expect(recipe.category, null);    // empty → null
    });

    test('fromJson parses directions from bullet-separated single string', () {
      final recipe = Recipe.fromJson({
        'id': '1',
        'name': 'A',
        'directions': ['• Step one\n• Step two\n• Step three'],
      });
      // Should split into 3 steps
      expect(recipe.directions.length, greaterThanOrEqualTo(2));
    });

    test('fromJson parses nutrition from top-level calorie fields', () {
      final recipe = Recipe.fromJson({
        'id': '1',
        'name': 'A',
        'calories': 250,
        'protein': 10,
        'carbs': 30,
        'total_fat': 8,
      });
      expect(recipe.nutrition, isNotNull);
      expect(recipe.nutrition!['Calories'], contains('250'));
      expect(recipe.nutrition!['Protein'], contains('10'));
    });

    test('fromJson extracts baseServings from text like "4 servings"', () {
      final recipe = Recipe.fromJson({
        'id': '1', 'name': 'A',
        'serving_size': '4 servings',
      });
      expect(recipe.baseServings, 4);
    });

    test('fromJson isNutritionistRecipe defaults to false', () {
      final recipe = Recipe.fromJson({'id': '1', 'name': 'A'});
      expect(recipe.isNutritionistRecipe, false);
    });

    test('fromJson isPublic defaults to true', () {
      final recipe = Recipe.fromJson({'id': '1', 'name': 'A'});
      expect(recipe.isPublic, true);
    });
  });
}
