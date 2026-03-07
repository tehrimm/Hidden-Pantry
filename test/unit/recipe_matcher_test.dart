import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/utils/recipe_matcher.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

void main() {
  test('normalize and isMatch work with plurals', () {
    expect(RecipeMatcher.normalize('Tomatoes'), 'tomato'); // simple stemming
    expect(RecipeMatcher.isMatch('Onions', ['onion']), isTrue);
  });

  test('getWeight returns custom or default', () {
    expect(RecipeMatcher.getWeight('saffron') > 1.0, isTrue);
    expect(RecipeMatcher.getWeight('unknown'), 1.0);
  });

  test('calculateMatch prefers stronger coverage for present pantry items', () {
    final r1 = Recipe(
      id: '1',
      name: 'Chicken Soup',
      minutes: 30,
      avgRating: 3.5,
      ingredients: const [
        IngredientItem(name: 'chicken', quantity: 1, unit: 'pc'),
        IngredientItem(name: 'salt', quantity: 1, unit: 'tsp'),
        IngredientItem(name: 'water', quantity: 1, unit: 'cup'),
      ],
    );
    final r2 = Recipe(
      id: '2',
      name: 'Saffron Rice',
      minutes: 30,
      avgRating: 4.5,
      ingredients: const [
        IngredientItem(name: 'saffron', quantity: 1, unit: 'pinch'),
        IngredientItem(name: 'rice', quantity: 1, unit: 'cup'),
        IngredientItem(name: 'salt', quantity: 1, unit: 'tsp'),
      ],
    );

    final mChicken = RecipeMatcher.calculateMatch(r1, ['chicken', 'salt']);
    final mSaffronOnR2 = RecipeMatcher.calculateMatch(r2, ['chicken', 'salt']); // only salt matches here
    expect(mChicken > mSaffronOnR2, isTrue);
  });

  test('sortRecipesByMatch puts saffron recipe first when pantry has saffron', () {
    final r1 = Recipe(
      id: '1',
      name: 'Chicken Soup',
      minutes: 30,
      avgRating: 3.5,
      ingredients: const [
        IngredientItem(name: 'chicken', quantity: 1, unit: 'pc'),
        IngredientItem(name: 'salt', quantity: 1, unit: 'tsp'),
        IngredientItem(name: 'water', quantity: 1, unit: 'cup'),
      ],
    );
    final r2 = Recipe(
      id: '2',
      name: 'Saffron Rice',
      minutes: 30,
      avgRating: 4.5,
      ingredients: const [
        IngredientItem(name: 'saffron', quantity: 1, unit: 'pinch'),
        IngredientItem(name: 'rice', quantity: 1, unit: 'cup'),
        IngredientItem(name: 'salt', quantity: 1, unit: 'tsp'),
      ],
    );

    final sorted = RecipeMatcher.sortRecipesByMatch([r1, r2], ['saffron', 'salt']);
    expect(sorted.first.id, '2');
  });
}
