import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/utils/recipe_matcher.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

Recipe r(String id, List<String> ings) => Recipe(
      id: id,
      name: id,
      minutes: 20,
      avgRating: 4.0,
      ingredients: ings.map((e) => IngredientItem(name: e, quantity: 1, unit: '')).toList(),
      directions: const [],
    );

void main() {
  group('[Unit][RecipeMatcher][Weighting]', () {
    final cases = <List<dynamic>>[
      [r('A', ['chicken', 'salt', 'onion']), ['chicken', 'salt']],
      [r('B', ['beef', 'garlic']), ['beef']],
      [r('C', ['saffron', 'salt']), ['saffron']],
      [r('D', ['salmon', 'water']), ['salmon']],
      [r('E', ['flour', 'sugar', 'water']), ['flour', 'sugar']],
    ];
    for (var i = 0; i < cases.length; i++) {
      test('[Unit][RecipeMatcher][Weighting] case-$i', () {
        final recipe = cases[i][0] as Recipe;
        final pantry = (cases[i][1] as List).cast<String>();
        final score = RecipeMatcher.calculateMatch(recipe, pantry);
        expect(score >= 0.0 && score <= 1.0, true);
      });
    }
  });
}

