import 'package:flutter_test/flutter_test.dart';

class Unread {
  final int nutritionistUnread;
  final int userUnread;
  const Unread(this.nutritionistUnread, this.userUnread);
}

Map<String, dynamic> buildMealPlanMessage(Map<String, dynamic> plan) {
  return {
    'type': 'meal_plan',
    'planId': plan['planId'],
    'title': plan['title'],
    'duration': plan['duration'],
    'targetCalories': plan['targetCalories'],
  };
}

Unread applyUnreadOnSend(Unread s, {required bool senderIsNutritionist}) {
  return senderIsNutritionist ? Unread(s.nutritionistUnread, s.userUnread + 1) : Unread(s.nutritionistUnread + 1, s.userUnread);
}

void main() {
  group('Integration: Meal plan chat payload + unread', () {
    test('Builds payload with expected fields and updates unread counters', () {
      final plan = {
        'planId': 'mp_1',
        'title': 'Cutting Plan',
        'duration': 7,
        'targetCalories': 1800,
      };
      final msg = buildMealPlanMessage(plan);
      expect(msg['type'], 'meal_plan');
      expect(msg['planId'], 'mp_1');
      expect(msg['title'], 'Cutting Plan');
      expect(msg['duration'], 7);
      expect(msg['targetCalories'], 1800);
      final u0 = Unread(0, 0);
      final u1 = applyUnreadOnSend(u0, senderIsNutritionist: true);
      expect(u1.userUnread, 1);
      final u2 = applyUnreadOnSend(u1, senderIsNutritionist: false);
      expect(u2.nutritionistUnread, 1);
    });
  });
}

