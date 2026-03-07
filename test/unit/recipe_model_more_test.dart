import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

void main() {
  test('toJson and fromJson round-trip fields', () {
    final r = Recipe(
      id: 'id',
      name: 'Name',
      minutes: 18,
      avgRating: 4.0,
      authorId: 'auth',
      authorName: 'Author',
      baseServings: 3,
      ingredients: const [
        IngredientItem(name: 'Flour', quantity: 1.5, unit: 'cup'),
        IngredientItem(name: 'Egg', quantity: 2, unit: 'pcs'),
      ],
      directions: const ['Mix', 'Bake'],
      nutrition: const {'Calories': '120 kcal', 'Protein': '10 g'},
      tags: const ['baking', 'dessert'],
      nSteps: 2,
      isPublic: true,
    );
    final m = r.toJson();
    final r2 = Recipe.fromJson(m);
    expect(r2.id, 'id');
    expect(r2.name, 'Name');
    expect(r2.minutes, 18);
    expect(r2.avgRating, 4.0);
    expect(r2.baseServings, 3);
    expect(r2.ingredients.length, 2);
    expect(r2.directions.length, 2);
    expect(r2.tags.contains('baking'), true);
    expect(r2.isPublic, true);
  });

  test('helpers parse ints and doubles from varied inputs', () {
    final r = Recipe.fromJson({
      'id': 'x',
      'title': 'T',
      'minutes': '35',
      'avg_rating': '3.3',
      'serving_size': '16 servings',
      'ingredients': ['Sugar', "{name:'Milk', quantity:'1/2', unit:'cup'}"],
      'directions': "1. Step\n2. Step",
      'nutrition': {'Calories': '200 kcal'},
      'tags': "['sweet','baking']",
      'n_steps': '2',
      'is_public': true,
    });
    expect(r.minutes, 35);
    expect(r.avgRating, 3.3);
    expect(r.baseServings, 16);
    expect(r.ingredients.first.name.toLowerCase(), 'sugar');
    expect(r.ingredients.last.quantity, 0.0);
    expect(r.directions.length >= 2, true);
    expect(r.tags.contains('sweet'), true);
    expect(r.calculatedTotalCalories >= 200, true);
    final scaled = r.getScaledNutrition(32);
    expect((scaled?['Calories'] ?? '').contains('400'), true);
  });

  test('copyWith preserves unspecified fields', () {
    final r = Recipe(
      id: 'a',
      name: 'N',
      minutes: 10,
      avgRating: 2.5,
      reviewCount: 1,
      authorId: 'auth',
      authorName: 'A',
      baseServings: 2,
      ingredients: const [],
      directions: const [],
      isPublic: true,
    );
    final r2 = r.copyWith(name: 'N2', avgRating: 3.7, isPublic: false);
    expect(r2.name, 'N2');
    expect(r2.avgRating, 3.7);
    expect(r2.isPublic, false);
    expect(r2.id, 'a');
    expect(r2.baseServings, 2);
  });
}
