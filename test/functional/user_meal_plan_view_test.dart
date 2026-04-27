import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/user/screens/meal_plan_view.dart';
import 'test_utils.dart';
import 'mock_firebase.dart';
import 'package:firebase_core/firebase_core.dart';

void main() {
  setUpAll(() async {
    setupFirebaseAuthMocks();
    await Firebase.initializeApp();
    setUpNetworkImageMock();
  });

  Widget wrap(Widget child) {
    return MaterialApp(
      home: child,
    );
  }

  void setupScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3.0;
  }

  void resetScreen(WidgetTester tester) {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  final testPlanData = {
    "planId": "test_plan_1",
    "title": "Keto Kickstart",
    "targetCalories": "2000",
    "duration": 3,
    "notes": "Drink lots of water.",
    "days": [
      {
        "day": 1,
        "meals": [
          {
            "recipeId": "r1",
            "type": "Breakfast",
            "title": "Avocado Egg Bake",
            "calories": 400,
            "protein": "20g",
            "carbs": "5g",
            "fats": "30g"
          },
          {
            "recipeId": "r2",
            "type": "Dinner",
            "title": "Steak and Broccoli",
            "calories": 600,
            "protein": "45g",
            "carbs": "10g",
            "fats": "40g"
          }
        ]
      },
      {
        "day": 2,
        "meals": [
          {
            "recipeId": "r3",
            "type": "Lunch",
            "title": "Chicken Salad",
            "calories": 500,
            "protein": "40g",
            "carbs": "15g",
            "fats": "20g"
          }
        ]
      },
      {
        "day": 3,
        "meals": [] // Rest day
      }
    ]
  };

  group('User Meal Plan View Functional Tests', () {
    testWidgets('Renders meal plan details correctly', (tester) async {
      setupScreen(tester);
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(wrap(MealPlanViewScreen(planData: testPlanData)));
      await tester.pumpAndSettle();

      expect(find.text('Keto Kickstart'), findsOneWidget);
      expect(find.text('Drink lots of water.'), findsOneWidget);
      expect(find.text('~2000'), findsOneWidget);
      
      // Check Day 1 total
      expect(find.text('Total for Day 1'), findsOneWidget);
      expect(find.text('1000 kcal'), findsOneWidget); // 400 + 600

      // Check meals are rendered
      expect(find.text('Avocado Egg Bake'), findsOneWidget);
      expect(find.text('Steak and Broccoli'), findsOneWidget);
    });

    testWidgets('User can switch days using timeline', (tester) async {
      setupScreen(tester);
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(wrap(MealPlanViewScreen(planData: testPlanData)));
      await tester.pumpAndSettle();

      // Tap Day 2
      final day2Finder = find.text('Day 2');
      await tester.tap(day2Finder);
      await tester.pumpAndSettle();

      // Check Day 2 total and meals
      expect(find.text('Total for Day 2'), findsOneWidget);
      expect(find.text('500 kcal'), findsOneWidget);
      expect(find.text('Chicken Salad'), findsOneWidget);

      // Tap Day 3 (Rest day)
      final day3Finder = find.text('Day 3');
      await tester.tap(day3Finder);
      await tester.pumpAndSettle();

      expect(find.text('Rest day. No meals planned.'), findsOneWidget);
    });

    testWidgets('Save to My Plans button renders when viewing public plan', (tester) async {
      setupScreen(tester);
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(wrap(MealPlanViewScreen(planData: testPlanData, isViewingSavedPlan: false)));
      await tester.pumpAndSettle();

      expect(find.text('Save to My Plans'), findsOneWidget);
    });

    testWidgets('Remove from My Plans button renders when viewing saved plan', (tester) async {
      setupScreen(tester);
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(wrap(MealPlanViewScreen(planData: testPlanData, isViewingSavedPlan: true)));
      await tester.pumpAndSettle();

      expect(find.text('Remove from My Plans'), findsOneWidget);
    });
  });
}
