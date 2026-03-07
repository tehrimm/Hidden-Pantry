import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/utils/recipe_matcher.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

Recipe r(String id, List<String> ings, {double rating = 4.0, int minutes = 20}) => Recipe(
      id: id,
      name: id,
      minutes: minutes,
      avgRating: rating,
      ingredients: ings.map((e) => IngredientItem(name: e, quantity: 1, unit: '')).toList(),
      directions: const [],
    );

void main() {
  group('[Unit][RecipeMatcher][Sorting]', () {
    test('[Unit][RecipeMatcher][Sorting] simple salt tie', () {
      final list = [r('R1', ['salt']), r('R2', ['salt']), r('R3', ['salt'])];
      final sorted = RecipeMatcher.sortRecipesByMatch(list, ['salt']);
      expect(sorted.length, 3);
    });

    test('[Unit][RecipeMatcher][Sorting] chicken + salt mix', () {
      final list = [r('R4', ['chicken']), r('R5', ['chicken', 'salt']), r('R6', ['salt'])];
      final sorted = RecipeMatcher.sortRecipesByMatch(list, ['salt', 'chicken']);
      expect(sorted.length, 3);
    });
  });
}

