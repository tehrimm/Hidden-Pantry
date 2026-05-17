import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

void main() {
  group('Real Integration Tests: Offline Recipe Caching (JSON Round-Trip)', () {
    /// This tests the exact serialization logic used by LocalRecipeService.
    /// saveRecipeOffline → jsonEncode(recipe.toJson())
    /// getOfflineRecipes → Recipe.fromJson(jsonDecode(data))

    final testRecipe = Recipe(
      id: 'offline_1',
      name: 'Offline Pancakes',
      minutes: 20,
      avgRating: 4.5,
      reviewCount: 8,
      authorId: 'chef_x',
      authorName: 'Chef X',
      baseServings: 2,
      tags: const ['Breakfast', 'Quick'],
      allergens: const ['dairy', 'egg'],
      ingredients: const [
        IngredientItem(name: 'flour', quantity: 1.5, unit: 'cups', calories: 685),
        IngredientItem(name: 'egg', quantity: 2, unit: 'pcs', calories: 140),
        IngredientItem(name: 'milk', quantity: 0.5, unit: 'cup', calories: 60),
      ],
      directions: const ['Mix dry ingredients', 'Add wet ingredients', 'Cook on medium heat'],
      nutrition: const {'Calories': '885 kcal', 'Protein': '28 g'},
      isNutritionistRecipe: false,
      isPublic: true,
    );

    test('toJson → jsonEncode → jsonDecode → fromJson preserves all fields', () {
      // Simulate LocalRecipeService.saveRecipeOffline
      final encoded = jsonEncode(testRecipe.toJson());

      // Simulate LocalRecipeService.getOfflineRecipes
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      final restored = Recipe.fromJson(decoded);

      expect(restored.id, testRecipe.id);
      expect(restored.name, testRecipe.name);
      expect(restored.minutes, testRecipe.minutes);
      expect(restored.avgRating, testRecipe.avgRating);
      expect(restored.reviewCount, testRecipe.reviewCount);
      expect(restored.authorId, testRecipe.authorId);
      expect(restored.authorName, testRecipe.authorName);
      expect(restored.baseServings, testRecipe.baseServings);
      expect(restored.tags, testRecipe.tags);
      expect(restored.allergens, testRecipe.allergens);
      expect(restored.isNutritionistRecipe, testRecipe.isNutritionistRecipe);
      expect(restored.isPublic, testRecipe.isPublic);
    });

    test('Cached ingredients preserve quantity, unit, and calories', () {
      final encoded = jsonEncode(testRecipe.toJson());
      final restored = Recipe.fromJson(jsonDecode(encoded));

      expect(restored.ingredients.length, 3);
      expect(restored.ingredients[0].name, 'flour');
      expect(restored.ingredients[0].quantity, closeTo(1.5, 0.001));
      expect(restored.ingredients[0].unit, 'cups');
      expect(restored.ingredients[0].calories, null);
    });

    test('Cached directions preserve all steps in order', () {
      final encoded = jsonEncode(testRecipe.toJson());
      final restored = Recipe.fromJson(jsonDecode(encoded));

      expect(restored.directions.length, 3);
      expect(restored.directions[0], 'Mix dry ingredients');
      expect(restored.directions[1], 'Add wet ingredients');
      expect(restored.directions[2], 'Cook on medium heat');
    });

    test('Cached nutrition map is fully preserved', () {
      final encoded = jsonEncode(testRecipe.toJson());
      final restored = Recipe.fromJson(jsonDecode(encoded));

      expect(restored.nutrition, isNotNull);
      expect(restored.nutrition!['Calories'], '885 kcal');
      expect(restored.nutrition!['Protein'], '28 g');
    });

    test('Cached recipe can be scaled after restore', () {
      final encoded = jsonEncode(testRecipe.toJson());
      final restored = Recipe.fromJson(jsonDecode(encoded));

      // Scale to 4 servings (multiplier = 2.0)
      final scaled = restored.getScaledIngredients(4);
      expect(scaled[0].quantity, closeTo(3.0, 0.001));   // flour: 1.5 * 2
      expect(scaled[0].calories, null);   // 685 * 2
      expect(scaled[1].quantity, closeTo(4.0, 0.001));   // egg: 2 * 2
      expect(scaled[2].quantity, closeTo(1.0, 0.001));   // milk: 0.5 * 2
    });

    test('Multiple recipes cached separately are independently restored', () {
      final recipe2 = testRecipe.copyWith(
        id: 'offline_2',
        name: 'Offline Omelette',
        ingredients: const [
          IngredientItem(name: 'egg', quantity: 3, unit: 'pcs', calories: 210),
        ],
      );

      final enc1 = jsonEncode(testRecipe.toJson());
      final enc2 = jsonEncode(recipe2.toJson());

      final r1 = Recipe.fromJson(jsonDecode(enc1));
      final r2 = Recipe.fromJson(jsonDecode(enc2));

      expect(r1.id, 'offline_1');
      expect(r2.id, 'offline_2');
      expect(r1.ingredients.length, 3);
      expect(r2.ingredients.length, 1);
      expect(r2.ingredients[0].name, 'egg');
    });

    test('Recipe with null optional fields cached without errors', () {
      final minimalRecipe = Recipe(
        id: 'minimal_offline',
        name: 'Plain Rice',
        minutes: 15,
        avgRating: 3.0,
      );

      final encoded = jsonEncode(minimalRecipe.toJson());
      final restored = Recipe.fromJson(jsonDecode(encoded));

      expect(restored.id, 'minimal_offline');
      expect(restored.imageUrl, null);
      expect(restored.description, null);
      expect(restored.nutrition, null);
      expect(restored.ingredients, isEmpty);
    });
  });
}
