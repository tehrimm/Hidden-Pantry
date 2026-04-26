import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/utils/recipe_matcher.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

Recipe _makeRecipe(String id, String ingredientName) {
  return Recipe(
    id: id,
    name: 'Test $id',
    minutes: 10,
    avgRating: 4.0,
    ingredients: [IngredientItem(name: ingredientName, quantity: 1, unit: 'unit')],
  );
}

void main() {
  group('Real Business Tests: RecipeMatcher Allergy Synonyms', () {
    group('Dairy synonyms', () {
      test('milk triggers dairy allergy', () {
        expect(RecipeMatcher.isSafe(_makeRecipe('1', 'milk'), ['dairy']), false);
      });

      test('cheddar cheese triggers dairy allergy', () {
        expect(RecipeMatcher.isSafe(_makeRecipe('2', 'cheddar'), ['dairy']), false);
      });

      test('butter triggers dairy allergy', () {
        expect(RecipeMatcher.isSafe(_makeRecipe('3', 'butter'), ['dairy']), false);
      });

      test('yogurt triggers dairy allergy', () {
        expect(RecipeMatcher.isSafe(_makeRecipe('4', 'yogurt'), ['dairy']), false);
      });

      test('coconut oil does NOT trigger dairy allergy', () {
        expect(RecipeMatcher.isSafe(_makeRecipe('5', 'coconut oil'), ['dairy']), true);
      });
    });

    group('Egg synonyms', () {
      test('egg yolk triggers egg allergy', () {
        expect(RecipeMatcher.isSafe(_makeRecipe('6', 'egg yolk'), ['egg']), false);
      });

      test('egg white triggers egg allergy', () {
        expect(RecipeMatcher.isSafe(_makeRecipe('7', 'egg white'), ['egg']), false);
      });

      test('scrambled eggs triggers egg allergy', () {
        expect(RecipeMatcher.isSafe(_makeRecipe('8', 'scrambled eggs'), ['egg']), false);
      });
    });

    group('Wheat / Gluten synonyms', () {
      test('flour triggers wheat allergy', () {
        expect(RecipeMatcher.isSafe(_makeRecipe('9', 'flour'), ['wheat']), false);
      });

      test('bread triggers gluten allergy', () {
        expect(RecipeMatcher.isSafe(_makeRecipe('10', 'bread'), ['gluten']), false);
      });
    });

    group('Fish synonyms', () {
      test('tuna triggers fish allergy', () {
        expect(RecipeMatcher.isSafe(_makeRecipe('11', 'tuna'), ['fish']), false);
      });

      test('salmon triggers fish allergy', () {
        expect(RecipeMatcher.isSafe(_makeRecipe('12', 'salmon'), ['fish']), false);
      });

      test('chicken does NOT trigger fish allergy', () {
        expect(RecipeMatcher.isSafe(_makeRecipe('13', 'chicken'), ['fish']), true);
      });
    });

    group('Tree Nut synonyms', () {
      test('almond triggers tree nut allergy', () {
        expect(RecipeMatcher.isSafe(_makeRecipe('14', 'almond'), ['tree nut']), false);
      });

      test('cashew triggers tree nut allergy', () {
        expect(RecipeMatcher.isSafe(_makeRecipe('15', 'cashew'), ['tree nut']), false);
      });

      test('walnut triggers tree nut allergy', () {
        expect(RecipeMatcher.isSafe(_makeRecipe('16', 'walnut'), ['tree nut']), false);
      });
    });

    group('Spicy synonyms', () {
      test('sriracha triggers spicy allergy', () {
        expect(RecipeMatcher.isSafe(_makeRecipe('17', 'sriracha'), ['spicy']), false);
      });

      test('jalapeño triggers spicy allergy', () {
        expect(RecipeMatcher.isSafe(_makeRecipe('18', 'jalapeno'), ['spicy']), false);
      });

      test('paprika triggers spicy allergy', () {
        expect(RecipeMatcher.isSafe(_makeRecipe('19', 'paprika'), ['spicy']), false);
      });
    });

    group('Multiple allergies compound tests', () {
      test('Multiple allergens: blocks recipe with ANY match', () {
        // Recipe has milk, which triggers dairy. User also has fish allergy.
        final recipe = _makeRecipe('20', 'milk');
        expect(RecipeMatcher.isSafe(recipe, ['fish', 'dairy']), false);
      });

      test('Multiple allergens: safe recipe passes all checks', () {
        final safeRecipe = Recipe(
          id: '21', name: 'Safe', minutes: 10, avgRating: 4.0,
          ingredients: [
            const IngredientItem(name: 'olive oil', quantity: 1, unit: 'tbsp'),
            const IngredientItem(name: 'garlic', quantity: 2, unit: 'cloves'),
          ],
        );
        expect(RecipeMatcher.isSafe(safeRecipe, ['dairy', 'fish', 'gluten', 'egg']), true);
      });

      test('calculateMatch returns 0.0 when any allergen present', () {
        final dangerRecipe = Recipe(
          id: '22', name: 'Danger', minutes: 10, avgRating: 4.0,
          ingredients: [
            const IngredientItem(name: 'chicken', quantity: 1, unit: 'breast'),
            const IngredientItem(name: 'butter', quantity: 2, unit: 'tbsp'), // dairy!
          ],
        );
        final score = RecipeMatcher.calculateMatch(
          dangerRecipe,
          ['chicken', 'butter'],
          allergies: ['dairy'],
        );
        expect(score, 0.0);
      });
    });
  });
}
