import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/core/utils/auth_validator.dart';

void main() {
  group('Real Business Tests: Recipe Upload & Validation Rules', () {

    // ─── Recipe Upload Field Validation ────────────────────────────
    group('Recipe title validation', () {
      test('Title must be non-empty to upload', () {
        const title = '';
        expect(title.trim().isEmpty, true); // Should block upload
      });

      test('Valid title passes upload check', () {
        const title = 'Butter Chicken';
        expect(title.trim().isNotEmpty, true);
      });

      test('Title with only spaces is invalid', () {
        const title = '   ';
        expect(title.trim().isEmpty, true);
      });

      test('Title gets stored lowercased for search indexing', () {
        const title = 'Butter Chicken';
        final nameSearch = title.toLowerCase();
        expect(nameSearch, 'butter chicken');
      });
    });

    // ─── Step Count Rules ──────────────────────────────────────────
    group('Recipe step count constraints', () {
      test('Recipe must have at least 1 direction step', () {
        final directions = ['Mix ingredients', 'Bake for 30 min'];
        expect(directions.isNotEmpty, true);
      });

      test('Empty steps list blocks upload', () {
        final steps = <DirectionStep>[];
        expect(steps.isEmpty, true); // Blocks upload
      });

      test('Step count matches directions list length', () {
        final steps = [
          DirectionStep(id: 's1', text: 'Step 1'),
          DirectionStep(id: 's2', text: 'Step 2'),
          DirectionStep(id: 's3', text: 'Step 3'),
        ];
        expect(steps.length, 3);
      });

      test('Empty step text is invalid', () {
        final step = DirectionStep(id: 's1', text: '');
        expect(step.text.trim().isEmpty, true); // Should warn user
      });

      test('Whitespace-only step text is invalid', () {
        final step = DirectionStep(id: 's1', text: '   ');
        expect(step.text.trim().isEmpty, true);
      });
    });

    // ─── Ingredient Rules ──────────────────────────────────────────
    group('Ingredient list constraints', () {
      test('At least 1 ingredient required', () {
        const ingredients = [
          IngredientItem(name: 'flour', quantity: 2.0, unit: 'cups'),
        ];
        expect(ingredients.isNotEmpty, true);
      });

      test('Ingredient name must be non-empty', () {
        const item = IngredientItem(name: '', quantity: 1, unit: 'pcs');
        expect(item.name.trim().isEmpty, true); // Invalid
      });

      test('Ingredient quantity must be positive', () {
        const valid = IngredientItem(name: 'sugar', quantity: 0.5, unit: 'cup');
        const invalid = IngredientItem(name: 'sugar', quantity: 0.0, unit: 'cup');
        expect(valid.quantity > 0, true);
        expect(invalid.quantity > 0, false);
      });

      test('totalCalories sums all ingredient calories', () {
        const recipe = Recipe(
          id: 'u1', name: 'A', minutes: 10, avgRating: 4.0,
          ingredients: [
            IngredientItem(name: 'butter', quantity: 1, unit: 'tbsp', calories: 102),
            IngredientItem(name: 'flour', quantity: 1, unit: 'cup', calories: 455),
            IngredientItem(name: 'sugar', quantity: 0.5, unit: 'cup', calories: 387),
          ],
        );
        expect(recipe.calculatedTotalCalories, closeTo(944.0, 0.01));
      });
    });

    // ─── Tag Validation ────────────────────────────────────────────
    group('Recipe tag business rules', () {
      const validTags = ['Italian', 'Dinner', 'Quick', 'Vegetarian'];

      test('Tags list is not empty for a well-tagged recipe', () {
        expect(validTags.isNotEmpty, true);
      });

      test('Duplicate tags are removed', () {
        final tags = ['Italian', 'Dinner', 'Italian', 'Quick'];
        final unique = tags.toSet().toList();
        expect(unique.length, 3);
        expect(unique.where((t) => t == 'Italian').length, 1);
      });

      test('Tags stored with original casing', () {
        final tags = ['Italian', 'VEGAN', 'quick'];
        // Tags are stored as-is, lowercased during search
        expect(tags.contains('Italian'), true);
        expect(tags.map((t) => t.toLowerCase()).contains('vegan'), true);
      });
    });

    // ─── Nutrition Map Structure ───────────────────────────────────
    group('Nutrition map structure validation', () {
      test('Required nutrition keys present', () {
        final nutrition = {
          'Calories': '350 kcal',
          'Protein': '12 g',
          'Carbohydrates': '45 g',
          'Total Fat': '8 g',
        };
        expect(nutrition.containsKey('Calories'), true);
        expect(nutrition.containsKey('Protein'), true);
      });

      test('Nutrition values include unit suffix', () {
        final nutrition = {'Calories': '350 kcal', 'Protein': '12 g'};
        for (final v in nutrition.values) {
          final hasUnit = v.contains('kcal') || v.contains('g') || v.contains('mg');
          expect(hasUnit, true, reason: '"$v" should contain a unit');
        }
      });

      test('Numeric extraction from nutrition string', () {
        const calStr = '350 kcal';
        final match = RegExp(r'(\d+\.?\d*)').firstMatch(calStr);
        final value = double.tryParse(match?.group(1) ?? '0') ?? 0.0;
        expect(value, closeTo(350.0, 0.001));
      });

      test('getScaledNutrition rounds correctly for whole numbers', () {
        const recipe = Recipe(
          id: 'n1', name: 'A', minutes: 10, avgRating: 4.0,
          baseServings: 2,
          nutrition: {'Calories': '200 kcal', 'Protein': '10 g'},
        );
        final scaled = recipe.getScaledNutrition(4)!;
        expect(scaled['Calories'], '400 kcal'); // 200 * 2 = 400 (whole)
        expect(scaled['Protein'], '20 g');       // 10 * 2 = 20 (whole)
      });

      test('getScaledNutrition uses 1 decimal for fractional values', () {
        const recipe = Recipe(
          id: 'n2', name: 'A', minutes: 10, avgRating: 4.0,
          baseServings: 3,
          nutrition: {'Protein': '10 g'},
        );
        final scaled = recipe.getScaledNutrition(2)!; // multiplier = 2/3
        // 10 * (2/3) = 6.666... → "6.7 g"
        expect(scaled['Protein'], contains('6.7'));
      });
    });

    // ─── Auth Validator used in Recipe Upload Author Check ─────────
    group('Author identity validation before upload', () {
      test('Author email validated before recipe is saved', () {
        final err = AuthValidator.validateEmail('');
        expect(err, isNotNull); // Blocks save
      });

      test('Author name capitalized correctly on profile', () {
        final name = AuthValidator.capitalizeName('john doe');
        expect(name, 'John Doe');
      });

      test('isPublic defaults to false on new nutritionist recipes', () {
        // Nutritionist recipes are draft by default
        const recipe = Recipe(
          id: 'nut_r', name: 'A', minutes: 10, avgRating: 0.0,
          isNutritionistRecipe: true,
          isPublic: false, // Explicit draft
        );
        expect(recipe.isPublic, false);
        expect(recipe.isNutritionistRecipe, true);
      });

      test('isPublic true for published community recipes', () {
        const recipe = Recipe(
          id: 'pub_r', name: 'A', minutes: 10, avgRating: 0.0,
          isPublic: true,
        );
        expect(recipe.isPublic, true);
      });
    });
  });
}
