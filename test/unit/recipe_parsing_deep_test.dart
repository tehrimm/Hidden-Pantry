import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

void main() {
  group('Recipe parsing deep coverage', () {
    test('parses nutrition in nested map and top-level fields', () {
      final r1 = Recipe.fromJson({
        'id': '1',
        'title': 'N1',
        'minutes': 10,
        'avg_rating': 3.5,
        'nutrition': {
          'Calories': '120 kcal',
          'Protein': '10 g',
        },
        'ingredients': ['salt', 'pepper'],
        'directions': ['do A', 'do B'],
      });
      expect(r1.nutrition, isNotNull);
      expect(r1.ingredients.length, 2);
      expect(r1.directions.length, 2);

      final r2 = Recipe.fromJson({
        'id': '2',
        'title': 'N2',
        'minutes': '25',
        'avg_rating': '4.2',
        'calories': 200,
        'protein': 12,
        'carbs': 30,
        'total_fat': 8,
        'sat_fat': 2,
        'sugar': 6,
        'sodium': 550,
        'ingredients_parsed': [
          {'name': 'Tomato', 'quantity': 2, 'unit': 'pcs', 'calories': 20},
          "{name: 'Flour', quantit: '1 1/2', unit: 'cup'}",
        ],
        'steps': "1. Mix\n2. Bake",
      });
      expect(r2.nutrition?['Calories'], contains('kcal'));
      expect(r2.ingredients.length, 2);
      expect(r2.directions.length, greaterThanOrEqualTo(2));
      expect(r2.baseServings, 1);
    });

    test('serving multiplier and scaled nutrition', () {
      final r = Recipe(
        id: 'x',
        name: 'Scale',
        minutes: 40,
        avgRating: 5.0,
        baseServings: 4,
        nutrition: {
          'Calories': '200 kcal',
          'Protein': '10 g',
        },
        ingredients: const [
          IngredientItem(name: 'Rice', quantity: 1.0, unit: 'cup', calories: 100),
          IngredientItem(name: 'Chicken', quantity: 0.5, unit: 'kg', calories: 300),
        ],
        directions: const [],
      );
      expect(r.getServingMultiplier(2), 0.5);
      expect(r.getServingMultiplier(0), 1.0);
      final scaled = r.getScaledNutrition(8);
      expect(scaled?['Calories'], contains('400'));
      final scaledIngs = r.getScaledIngredients(8);
      expect(scaledIngs.first.quantity, 2.0);
    });

    test('calculatedTotalCalories falls back to ingredient sum', () {
      final r = Recipe(
        id: 'y',
        name: 'Calc',
        minutes: 20,
        avgRating: 4.0,
        ingredients: const [
          IngredientItem(name: 'A', quantity: 1.0, unit: 'u', calories: 50),
          IngredientItem(name: 'B', quantity: 1.0, unit: 'u', calories: 75),
        ],
        directions: const [],
      );
      expect(r.calculatedTotalCalories, 125);
    });

    test('IngredientItem parsing robustness', () {
      final i1 = IngredientItem.fromJson({'name': 'Milk', 'quantity': '1/2', 'unit': 'cup'});
      expect(i1.quantity, closeTo(0.5, 0.0001));
      final i2 = IngredientItem.fromJson({'ingredient': 'Flour', 'quantiy': '1 1/2', 'unit': 'cup'});
      expect(i2.quantity, closeTo(1.5, 0.0001));
      final i3 = IngredientItem.fromJson({'name': "<b>Egg</b>", 'quantity': 2, 'unit': "<i>pcs</i>"});
      expect(i3.name, 'Egg');
      expect(i3.unit, 'pcs');
    });

    test('fromJson handles varied id/name fields and imageUrl mapping', () {
      final r = Recipe.fromJson({
        'recipe_id': 'abc',
        'recipe_name': 'Pasta',
        'total_time': 30,
        'recipe_average_rating': 4.3,
        'image_url': 'http://example.com/image.jpg',
        'author_id': 'auth1',
        'author_name': 'Chef Test',
        'tags': ['italian', 'pasta'],
        'n_steps': 3,
        'is_public': true,
      });
      expect(r.id, 'abc');
      expect(r.name, 'Pasta');
      expect(r.imageUrl, isNotNull);
      expect(r.tags, contains('italian'));
      expect(r.nSteps, 3);
      expect(r.isPublic, isTrue);
      expect(r.cookMinutes, greaterThanOrEqualTo(0));
      expect(r.prepMinutes, greaterThanOrEqualTo(0));
    });

    test('copyWith updates fields without losing others', () {
      final base = Recipe(
        id: 'id',
        name: 'Base',
        minutes: 10,
        avgRating: 3.0,
        ingredients: const [],
        directions: const [],
      );
      final changed = base.copyWith(name: 'Changed', avgRating: 4.5, isPublic: false);
      expect(changed.name, 'Changed');
      expect(changed.avgRating, 4.5);
      expect(changed.isPublic, isFalse);
      expect(changed.id, 'id');
    });
  });
}

