import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

void main() {
  group('Recipe Model Complete Coverage', () {
    test('Initialization and default values', () {
      final recipe = Recipe(
        id: '1',
        name: 'Test Recipe',
        minutes: 30,
        avgRating: 4.5,
      );

      expect(recipe.id, '1');
      expect(recipe.name, 'Test Recipe');
      expect(recipe.prepMinutes, 15); // Fallback logic
      expect(recipe.cookMinutes, 15); // Fallback logic
      expect(recipe.totalSteps, isNull);
      expect(recipe.isPublic, isTrue);
      expect(recipe.isNutritionistRecipe, isFalse);
    });

    test('getServingMultiplier scales correctly', () {
      final recipe = Recipe(
        id: '1',
        name: 'Scale Recipe',
        minutes: 30,
        avgRating: 4.5,
        baseServings: 2,
      );

      expect(recipe.getServingMultiplier(4), 2.0);
      expect(recipe.getServingMultiplier(1), 0.5);
      expect(recipe.getServingMultiplier(0), 1.0); // Invalid fallback
      expect(recipe.getServingMultiplier(-2), 1.0); // Invalid fallback
    });

    test('getScaledIngredients scales ingredient quantities and calories', () {
      final recipe = Recipe(
        id: '1',
        name: 'Ing Recipe',
        minutes: 30,
        avgRating: 4.0,
        baseServings: 2,
        ingredients: [
          IngredientItem(name: 'Flour', quantity: 100, unit: 'g', calories: 350.0),
        ],
      );

      final scaled = recipe.getScaledIngredients(4);
      expect(scaled.first.quantity, 200.0);
      expect(scaled.first.calories, 700.0);
    });

    test('getScaledNutrition formats and scales parsed string values', () {
      final recipe = Recipe(
        id: '1',
        name: 'Nut Recipe',
        minutes: 30,
        avgRating: 4.0,
        baseServings: 2,
        nutrition: {
          'Calories': '200.5 kcal',
          'Protein': '10 g',
          'Empty': 'N/A', // Unscalable
        },
      );

      final scaled = recipe.getScaledNutrition(4)!;
      expect(scaled['Calories'], '401 kcal'); // 200.5 * 2 = 401.0 -> 401
      expect(scaled['Protein'], '20 g');
      expect(scaled['Empty'], 'N/A');
    });

    test('calculatedTotalCalories handles nutrition map parsing and fallback', () {
      // With nutrition map
      final recipeA = Recipe(
        id: '1',
        name: 'A',
        minutes: 30,
        avgRating: 4.0,
        nutrition: {'Calories': '350.5 kcal'},
        ingredients: [IngredientItem(name: 'Apple', quantity: 1, unit: '', calories: 100)],
      );
      expect(recipeA.calculatedTotalCalories, 350.5);

      // Without nutrition map (fallback to ingredients sum)
      final recipeB = Recipe(
        id: '2',
        name: 'B',
        minutes: 30,
        avgRating: 4.0,
        ingredients: [
          IngredientItem(name: 'Apple', quantity: 1, unit: '', calories: 100.5),
          IngredientItem(name: 'Banana', quantity: 1, unit: '', calories: 90.0),
          IngredientItem(name: 'Water', quantity: 1, unit: ''), // Null calories
        ],
      );
      expect(recipeB.calculatedTotalCalories, 190.5);
    });

    test('getNutrient handles aliases and direct matches', () {
      final recipe = Recipe(
        id: '1',
        name: 'Nut',
        minutes: 10,
        avgRating: 5.0,
        nutrition: {
          'p': '20g', // Map contains the alias
          'Carbohydrates': '50g',
          'total fat': '15g', // Map contains the alias
        },
      );

      // Direct match works
      expect(recipe.getNutrient('Carbohydrates'), '50g');
      
      // Requesting the canonical name searches for aliases in the map
      expect(recipe.getNutrient('Protein'), '20g'); 
      expect(recipe.getNutrient('Fats'), '15g'); 
      expect(recipe.getNutrient('Fiber'), '0g'); // Missing
    });
    
    test('fromJson and toJson mapping covers all properties', () {
      final jsonMap = {
        'id': '123',
        'name': 'Pasta',
        'description': 'Delicious pasta',
        'category': 'Dinner',
        'allergens': ['Gluten', 'Dairy'], // Maps to allergens
        'difficulty': 'Medium',
        'serving_size': '2 servings',
        'minutes': 45,
        'prep_minutes': 15,
        'cook_minutes': 30,
        'avg_rating': 4.8,
        'review_count': 100,
        'author_id': 'u1',
        'author_name': 'Chef',
        'base_servings': 4,
        'ingredients': [
          {'name': 'Pasta', 'quantity': 200, 'unit': 'g', 'calories': 300.0}
        ],
        'directions': ['Boil water', 'Add pasta'],
        'nutrition': {'Calories': '500 kcal'},
        'tags': ['Italian'],
        'steps_detailed': [{'id': 's1', 'text': 'Boil water'}],
        'n_steps': 2,
        'is_nutritionist_recipe': true,
        'is_public': false,
      };

      final recipe = Recipe.fromJson(jsonMap);
      
      expect(recipe.id, '123');
      expect(recipe.name, 'Pasta');
      expect(recipe.allergens.contains('Gluten'), isTrue);
      expect(recipe.ingredients.length, 1);
      expect(recipe.directions.length, 2);
      expect(recipe.isNutritionistRecipe, isTrue);
      expect(recipe.isPublic, isFalse);
      
      final exportedJson = recipe.toJson();
      expect(exportedJson['name'], 'Pasta');
      expect(exportedJson['minutes'], 45);
      expect(exportedJson['is_public'], false);
      expect(exportedJson['is_nutritionist_recipe'], true);
    });
  });
}
