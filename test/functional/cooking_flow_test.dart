
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hidden_pantry_app/features/recipes/screens/cooking_details.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'test_utils.dart';
import 'mock_firebase.dart';

void main() {
  setUpAll(() async {
    setupFirebaseAuthMocks();
    await Firebase.initializeApp();
    setUpNetworkImageMock();
  });

  /// Build a minimal test recipe with 2 cooking steps.
  Recipe buildTestRecipe() {
    return Recipe(
      id: 'cook-test-1',
      name: 'Simple Omelette',
      authorId: 'chef-1',
      imageUrl: 'http://example.com/omelette.jpg',
      minutes: 15,
      avgRating: 4.5,
      ingredients: [
        IngredientItem(name: 'Eggs', quantity: 3, unit: 'pcs'),
        IngredientItem(name: 'Salt', quantity: 0.25, unit: 'tsp'),
      ],
      directions: [
        'Crack the eggs into a bowl and whisk until combined.',
        'Pour the egg mixture into a hot pan and cook for 2 minutes.',
      ],
      baseServings: 2,
    );
  }

  Widget createTestWidget(Widget child) {
    return MaterialApp(home: child);
  }

  testWidgets(
    'Cooking Flow: Launch Screen -> View Step 1 -> Swipe to Step 2 -> Finish & Review appears',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final recipe = buildTestRecipe();

      await tester.pumpWidget(createTestWidget(
        CookingDetailsScreen(recipe: recipe, initialServings: 2),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Verify step counter shows step 1
      expect(find.text('Step 1 of 2'), findsOneWidget);

      // 2. Verify step 1 direction text is visible
      expect(
        find.text('Crack the eggs into a bowl and whisk until combined.'),
        findsOneWidget,
      );

      // 3. Verify 'Ingredient' link is visible
      expect(find.text('Ingredient'), findsOneWidget);

      // 4. Verify play button exists (play icon is shown when not playing)
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      // 5. "Finish & Review" should NOT be shown yet (we're on step 1)
      expect(find.text('Finish & Review'), findsNothing);

      // 6. Swipe left on PageView to go to step 2
      await tester.drag(
        find.text('Crack the eggs into a bowl and whisk until combined.'),
        const Offset(-800, 0),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // 7. Verify step counter updated to step 2
      expect(find.text('Step 2 of 2'), findsOneWidget);

      // 8. Verify step 2 direction text is visible
      expect(
        find.text('Pour the egg mixture into a hot pan and cook for 2 minutes.'),
        findsOneWidget,
      );

      // 9. "Finish & Review" button should now appear (last step)
      expect(find.text('Finish & Review'), findsOneWidget);
    },
  );

  testWidgets(
    'Cooking Flow: Open Ingredient Drawer -> Verify ingredients listed',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final recipe = buildTestRecipe();

      await tester.pumpWidget(createTestWidget(
        CookingDetailsScreen(recipe: recipe, initialServings: 2),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap 'Ingredient' link to open the drawer
      await tester.tap(find.text('Ingredient'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify both ingredients appear in the drawer
      expect(find.text('Eggs'), findsOneWidget);
      expect(find.text('Salt'), findsOneWidget);
    },
  );
}
