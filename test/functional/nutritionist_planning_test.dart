import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hidden_pantry_app/features/nutritionist/screens/meal_plan_creator.dart';
import 'mock_firebase.dart';
import 'test_utils.dart';

void main() {
  setUpAll(() async {
    setupFirebaseAuthMocks();
    await Firebase.initializeApp();
    setUpNetworkImageMock();
  });

  Widget wrap(Widget child) => MaterialApp(home: child);

  void setupScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
  }

  void resetScreen(WidgetTester tester) {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  group('Meal Plan Creation Ecosystem Functional Tests', () {
    testWidgets('Meal Plan Creator displays basic sections', (tester) async {
      setupScreen(tester);
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(wrap(const MealPlanCreatorScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Create Meal Plan'), findsOneWidget);
      expect(find.text('Duration'), findsOneWidget);
      expect(find.text('DAY'), findsWidgets);
    });

    testWidgets('Meal Plan Creator can toggle duration', (tester) async {
      setupScreen(tester);
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(wrap(const MealPlanCreatorScreen()));
      await tester.pumpAndSettle();

      // Programmatically trigger the tap on '14 Days' to bypass hit testing clipping issues
      final duration14Finder = find.text('14 Days');
      final gdFinder = find.ancestor(of: duration14Finder, matching: find.byType(GestureDetector)).first;
      final gd = tester.widget<GestureDetector>(gdFinder);
      gd.onTap!();
      await tester.pumpAndSettle();
      
      // The day selector items scale with screen width (.sw), so Day 14 is always off-screen.
      // We explicitly drag the ListView incrementally to ensure we safely reach Day 14.
      final listFinder = find.byKey(const Key('day_selector_list'));
      
      bool found14 = false;
      for (int i = 0; i < 15; i++) {
        if (tester.any(find.text('14'))) {
          found14 = true;
          break;
        }
        await tester.drag(listFinder, const Offset(-300, 0), warnIfMissed: false);
        await tester.pumpAndSettle();
      }
      
      final day14Finder = find.text('14');
      await tester.pumpAndSettle();
      
      expect(found14, isTrue, reason: "Day 14 should become visible after scrolling right");
      
      expect(day14Finder, findsWidgets);
    });

    testWidgets('Meal Plan Creator can add notes to categories', (tester) async {
      setupScreen(tester);
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(wrap(const MealPlanCreatorScreen()));
      await tester.pumpAndSettle();

      // Tap Add Note in Breakfast section
      await tester.tap(find.widgetWithText(TextButton, 'Add Note').first);
      await tester.pumpAndSettle();

      expect(find.text('Add Note to Breakfast'), findsOneWidget);
      
      await tester.enterText(find.byType(TextField).last, 'Eat within 30 mins of waking up.');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Eat within 30 mins of waking up.'), findsOneWidget);
    });
  });
}
