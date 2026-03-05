import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

void main() {
  group('IngredientItem.fromJson', () {
    test('should parse standard JSON correctly', () {
      final json = {
        'name': 'Sugar',
        'quantity': 2.0,
        'unit': 'tbsp'
      };
      final item = IngredientItem.fromJson(json);
      expect(item.name, 'Sugar');
      expect(item.quantity, 2.0);
      expect(item.unit, 'tbsp');
    });

    test('should handle missing quantity and unit', () {
      final json = {'name': 'Salt'};
      final item = IngredientItem.fromJson(json);
      expect(item.name, 'Salt');
      expect(item.quantity, 0.0);
      expect(item.unit, '');
    });

    test('should strip HTML tags from name and unit', () {
      final json = {
        'name': '<b>Flour</b>',
        'quantity': 1,
        'unit': '<i>cup</i>'
      };
      final item = IngredientItem.fromJson(json);
      expect(item.name, 'Flour');
      expect(item.unit, 'cup');
    });

    test('should handle stringified map in name field', () {
      final json = {
        'name': "{'name': 'Butter', 'quantity': 100, 'unit': 'g'}",
      };
      final item = IngredientItem.fromJson(json);
      expect(item.name, 'Butter');
      expect(item.quantity, 100.0);
      expect(item.unit, 'g');
    });
  });

  group('Recipe.fromJson', () {
    test('should parse standard recipe JSON correctly', () {
      final json = {
        'id': '123',
        'title': 'Test Recipe',
        'minutes': 30,
        'avg_rating': 4.5,
        'ingredients': [
          {'name': 'Water', 'quantity': 1, 'unit': 'cup'}
        ],
        'directions': 'Step 1\nStep 2'
      };
      final recipe = Recipe.fromJson(json);
      expect(recipe.id, '123');
      expect(recipe.name, 'Test Recipe');
      expect(recipe.minutes, 30);
      expect(recipe.avgRating, 4.5);
      expect(recipe.ingredients.length, 1);
      expect(recipe.ingredients[0].name, 'Water');
      expect(recipe.directions, ['Step 1', 'Step 2']);
    });

    test('should handle robust serving size and baseServings parsing', () {
      final json = {
        'id': '1',
        'title': 'Recipe',
        'servings': '4 servings',
        'minutes': 10,
        'avg_rating': 5
      };
      final recipe = Recipe.fromJson(json);
      expect(recipe.baseServings, 4);
    });

    test('should parse nutrition correctly', () {
      final json = {
        'id': '1',
        'title': 'Healthy Salad',
        'minutes': 15,
        'avg_rating': 5,
        'calories': 200,
        'protein': 10,
        'carbs': 5,
        'total_fat': 15,
        'sugar': 2,
        'sodium': 100
      };
      final recipe = Recipe.fromJson(json);
      expect(recipe.nutrition?['Calories'], '200 kcal');
      expect(recipe.nutrition?['Protein'], '10 g');
    });

    test('should assign default values when optional JSON fields are missing', () {
      final json = {
        'id': 'def_1',
        'title': 'Default Recipe',
        'minutes': 10,
        'avg_rating': 4.0,
      };
      final recipe = Recipe.fromJson(json);
      // prepMinutes should default to minutes if minutes < 20
      expect(recipe.prepMinutes, 10);
      expect(recipe.baseServings, 1); // default fallback
    });

    test('should parse backend JSON with various key formats', () {
      final json = {
        'recipe_id': 'back_1',
        'recipe_name': 'Backend Recipe',
        'total_time': 45,
        'recipe_average_rating': 3.5,
        'n_servings': 6
      };
      final recipe = Recipe.fromJson(json);
      expect(recipe.id, 'back_1');
      expect(recipe.name, 'Backend Recipe');
      expect(recipe.minutes, 45);
      expect(recipe.baseServings, 6);
      // prepMinutes should default to 15 if minutes >= 20
      expect(recipe.prepMinutes, 15);
    });
  });
}
