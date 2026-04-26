import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

void main() {
  group('Real Business Tests: Recipe JSON & Serialization', () {
    late Recipe fullRecipe;

    setUp(() {
      fullRecipe = const Recipe(
        id: 'r_json_1',
        name: 'Serialization Pasta',
        minutes: 30,
        avgRating: 4.2,
        reviewCount: 18,
        authorId: 'chef_01',
        authorName: 'Gordon',
        baseServings: 4,
        tags: ['Italian', 'Dinner'],
        allergens: ['gluten'],
        ingredients: [
          IngredientItem(name: 'pasta', quantity: 200, unit: 'g', calories: 300),
          IngredientItem(name: 'egg', quantity: 2, unit: 'pcs', calories: 140),
        ],
        directions: ['Boil pasta', 'Mix with egg'],
        nutrition: {'Calories': '440 kcal', 'Protein': '15 g'},
        isNutritionistRecipe: false,
        isPublic: true,
      );
    });

    group('toJson / fromJson round-trip', () {
      test('toJson includes all core fields', () {
        final json = fullRecipe.toJson();
        expect(json['id'], 'r_json_1');
        expect(json['name'], 'Serialization Pasta');
        expect(json['avg_rating'], 4.2);
        expect(json['review_count'], 18);
        expect(json['author_id'], 'chef_01');
        expect(json['author_name'], 'Gordon');
        expect(json['base_servings'], 4);
        expect(json['is_nutritionist_recipe'], false);
        expect(json['is_public'], true);
      });

      test('fromJson reconstructs the recipe correctly', () {
        final json = fullRecipe.toJson();
        final restored = Recipe.fromJson(json);

        expect(restored.id, fullRecipe.id);
        expect(restored.name, fullRecipe.name);
        expect(restored.avgRating, fullRecipe.avgRating);
        expect(restored.authorId, fullRecipe.authorId);
        expect(restored.baseServings, fullRecipe.baseServings);
        expect(restored.ingredients.length, 2);
        expect(restored.ingredients.first.name, 'pasta');
        expect(restored.directions.length, 2);
      });

      test('fromJson round-trip preserves nutrition map', () {
        final json = fullRecipe.toJson();
        final restored = Recipe.fromJson(json);
        expect(restored.nutrition, isNotNull);
        expect(restored.nutrition!['Calories'], '440 kcal');
        expect(restored.nutrition!['Protein'], '15 g');
      });
    });

    group('copyWith immutability', () {
      test('copyWith preserves all non-modified fields', () {
        final modified = fullRecipe.copyWith(id: 'r_new', avgRating: 5.0);
        expect(modified.id, 'r_new');
        expect(modified.avgRating, 5.0);
        // All others unchanged
        expect(modified.name, 'Serialization Pasta');
        expect(modified.authorId, 'chef_01');
        expect(modified.ingredients.length, 2);
        expect(modified.directions.length, 2);
      });

      test('copyWith with new ingredients replaces list', () {
        final newIngs = [
          const IngredientItem(name: 'tomato', quantity: 3, unit: 'pcs')
        ];
        final modified = fullRecipe.copyWith(ingredients: newIngs);
        expect(modified.ingredients.length, 1);
        expect(modified.ingredients.first.name, 'tomato');
      });
    });

    group('IngredientItem parsing math', () {
      test('IngredientItem fromJson parses simple integer quantity', () {
        final item = IngredientItem.fromJson({'name': 'chicken', 'quantity': 2, 'unit': 'breasts'});
        expect(item.name, 'chicken');
        expect(item.quantity, 2.0);
        expect(item.unit, 'breasts');
      });

      test('IngredientItem fromJson parses fractional string quantity', () {
        // "1/2" should parse to 0.5
        final item = IngredientItem.fromJson({'name': 'butter', 'quantity': '1/2', 'unit': 'cup'});
        expect(item.quantity, closeTo(0.5, 0.001));
      });

      test('IngredientItem fromJson parses mixed fraction', () {
        // "1 3/4" should parse to 1.75
        final item = IngredientItem.fromJson({'name': 'flour', 'quantity': '1 3/4', 'unit': 'cups'});
        expect(item.quantity, closeTo(1.75, 0.001));
      });

      test('IngredientItem fromJson strips HTML tags from name', () {
        final item = IngredientItem.fromJson({'name': '<b>Salt</b>', 'quantity': 1, 'unit': 'tsp'});
        expect(item.name, 'Salt');
      });

      test('IngredientItem copyWith updates individual fields', () {
        const original = IngredientItem(name: 'milk', quantity: 1.0, unit: 'cup', calories: 150);
        final scaled = original.copyWith(quantity: 2.0, calories: 300);
        expect(scaled.name, 'milk');
        expect(scaled.quantity, 2.0);
        expect(scaled.calories, 300);
      });

      test('IngredientItem toJson includes all fields', () {
        const item = IngredientItem(name: 'sugar', quantity: 0.5, unit: 'cup', calories: 100);
        final map = item.toJson();
        expect(map['name'], 'sugar');
        expect(map['quantity'], 0.5);
        expect(map['unit'], 'cup');
        expect(map['calories'], 100);
      });
    });
  });
}
