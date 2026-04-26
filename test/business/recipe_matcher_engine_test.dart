import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/utils/recipe_matcher.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

void main() {
  group('Real Business Tests: RecipeMatcher Normalize & Weight Engine', () {

    group('normalize() — stemming rules', () {
      test('Trims leading/trailing whitespace', () {
        expect(RecipeMatcher.normalize('  chicken  '), 'chicken');
      });

      test('Lowercases the input', () {
        expect(RecipeMatcher.normalize('CHICKEN'), 'chicken');
        expect(RecipeMatcher.normalize('Salmon'), 'salmon');
      });

      test('Strips trailing s from plural nouns', () {
        expect(RecipeMatcher.normalize('eggs'), 'egg');
        expect(RecipeMatcher.normalize('carrots'), 'carrot');
        expect(RecipeMatcher.normalize('noodles'), 'noodle');
      });

      test('Does NOT strip s from words ending in ss', () {
        expect(RecipeMatcher.normalize('bass'), 'bass'); // fish
        expect(RecipeMatcher.normalize('glass'), 'glass');
      });

      test('Strips trailing es from plurals', () {
        expect(RecipeMatcher.normalize('Tomatoes'), 'tomato');
        expect(RecipeMatcher.normalize('potatoes'), 'potato');
      });

      test('Does not over-strip single-syllable words', () {
        expect(RecipeMatcher.normalize('peas'), 'pea');
        expect(RecipeMatcher.normalize('oats'), 'oat');
      });
    });

    group('getWeight() — rarity scoring', () {
      test('Returns correct weight for known ingredients', () {
        expect(RecipeMatcher.getWeight('chicken'), 1.5);
        expect(RecipeMatcher.getWeight('beef'), 1.5);
        expect(RecipeMatcher.getWeight('salmon'), 2.0);
        expect(RecipeMatcher.getWeight('saffron'), 3.0);
        expect(RecipeMatcher.getWeight('salt'), 0.1);
        expect(RecipeMatcher.getWeight('water'), 0.1);
        expect(RecipeMatcher.getWeight('flour'), 0.5);
        expect(RecipeMatcher.getWeight('sugar'), 0.5);
        expect(RecipeMatcher.getWeight('onion'), 0.8);
        expect(RecipeMatcher.getWeight('garlic'), 0.8);
      });

      test('Returns 1.0 default for unknown ingredients', () {
        expect(RecipeMatcher.getWeight('dragon fruit'), 1.0);
        expect(RecipeMatcher.getWeight('xyz'), 1.0);
        expect(RecipeMatcher.getWeight('pasta'), 0.5);
        expect(RecipeMatcher.getWeight('lemon'), 1.0);
      });

      test('Weight lookup normalizes the ingredient name before lookup', () {
        // 'Chicken' normalized to 'chicken' → 1.5
        expect(RecipeMatcher.getWeight('Chicken'), 1.5);
        // 'GARLIC' normalized to 'garlic' → 0.8
        expect(RecipeMatcher.getWeight('GARLIC'), 0.8);
      });
    });

    group('isMatch() — normalized comparison', () {
      test('Exact normalized match returns true', () {
        expect(RecipeMatcher.isMatch('chicken', ['chicken', 'garlic']), true);
      });

      test('Case-insensitive match', () {
        expect(RecipeMatcher.isMatch('Chicken', ['chicken']), true);
        expect(RecipeMatcher.isMatch('GARLIC', ['garlic']), true);
      });

      test('Plural match after normalization', () {
        // 'eggs' normalizes to 'egg', pantry has 'egg' which also normalizes to 'egg'
        expect(RecipeMatcher.isMatch('eggs', ['egg']), true);
      });

      test('No match returns false', () {
        expect(RecipeMatcher.isMatch('salmon', ['chicken', 'garlic']), false);
        expect(RecipeMatcher.isMatch('tuna', []), false);
      });
    });

    group('calculateMatch() — weighted score accuracy', () {
      test('Full pantry match returns 1.0', () {
        final recipe = const Recipe(
          id: 'w1', name: 'Test', minutes: 10, avgRating: 4.0,
          ingredients: [
            IngredientItem(name: 'chicken', quantity: 1, unit: 'g'), // 1.5
            IngredientItem(name: 'garlic', quantity: 1, unit: 'g'),  // 0.8
          ],
        );
        final score = RecipeMatcher.calculateMatch(recipe, ['chicken', 'garlic']);
        expect(score, closeTo(1.0, 0.001));
      });

      test('Empty ingredients returns 0.0', () {
        final emptyRecipe = const Recipe(
          id: 'w2', name: 'Empty', minutes: 5, avgRating: 3.0,
        );
        expect(RecipeMatcher.calculateMatch(emptyRecipe, ['chicken']), 0.0);
      });

      test('Rare ingredient (saffron weight=3.0) dominates score', () {
        // Recipe: saffron (3.0) + salt (0.1). Total=3.1
        // Pantry: only salt. Matched=0.1. Score = 0.1/3.1 ≈ 0.032
        final recipe = const Recipe(
          id: 'w3', name: 'Saffron Rice', minutes: 30, avgRating: 4.5,
          ingredients: [
            IngredientItem(name: 'saffron', quantity: 1, unit: 'pinch'),
            IngredientItem(name: 'salt', quantity: 1, unit: 'tsp'),
          ],
        );
        final score = RecipeMatcher.calculateMatch(recipe, ['salt']);
        expect(score, closeTo(0.032, 0.005));
      });
    });
  });
}
