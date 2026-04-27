import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/models/meal_plan.dart';

void main() {
  group('MealPlan Model Tests', () {
    test('Meal Plan model parses nested list of daily recipes correctly', () {
      final json = {
        'planId': 'plan_001',
        'title': '7 Day Fitness Plan',
        'duration': 7,
        'days': [
          {
            'day': 1,
            'meals': [
              {'title': 'Oatmeal', 'type': 'breakfast', 'calories': '300'},
              {'title': 'Chicken Salad', 'type': 'lunch', 'calories': '500'},
            ],
          },
          {
            'day': 2,
            'meals': [
              {'title': 'Smoothie', 'type': 'breakfast', 'calories': '250'},
            ],
          }
        ],
      };

      final plan = MealPlan.fromJson(json);

      expect(plan.id, 'plan_001');
      expect(plan.days.length, 2);
      expect(plan.days[0].day, 1);
      expect(plan.days[0].meals.length, 2);
      expect(plan.days[0].meals[0].title, 'Oatmeal');
      expect(plan.days[1].meals[0].title, 'Smoothie');
    });

    test('Meal type is parsed correctly from JSON', () {
      final json = {
        'planId': 'p2',
        'title': 'Single Day Plan',
        'duration': 1,
        'days': [
          {
            'day': 1,
            'meals': [
              {'title': 'Eggs', 'type': 'breakfast', 'calories': '200'},
            ],
          }
        ],
      };
      final plan = MealPlan.fromJson(json);
      expect(plan.days[0].meals[0].type, 'breakfast');
    });

    test('Meal calories string is stored correctly', () {
      final json = {
        'planId': 'p3',
        'title': 'Calorie Plan',
        'duration': 1,
        'days': [
          {
            'day': 1,
            'meals': [
              {'title': 'Salad', 'type': 'lunch', 'calories': '450'},
            ],
          }
        ],
      };
      final plan = MealPlan.fromJson(json);
      expect(plan.days[0].meals[0].calories, '450');
    });
  });
}
