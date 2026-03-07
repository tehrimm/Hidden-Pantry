import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/models/meal_plan.dart';

void main() {
  test('MealPlan parsing creates nested days and meals', () {
    final mp = MealPlan.fromJson({
      'planId': 'p1',
      'title': 'Week Plan',
      'duration': 7,
      'days': [
        {
          'day': 1,
          'meals': [
            {'title': 'Breakfast', 'type': 'breakfast', 'calories': 300},
            {'title': 'Lunch', 'type': 'lunch', 'calories': 600},
          ]
        }
      ]
    });
    expect(mp.id, 'p1');
    expect(mp.title, 'Week Plan');
    expect(mp.days.first.meals.length, 2);
    expect(mp.days.first.meals.first.title, 'Breakfast');
  });
}

