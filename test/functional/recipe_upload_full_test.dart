import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hidden_pantry_app/features/recipes/upload/upload_recipe_step1.dart';
import 'package:hidden_pantry_app/features/recipes/upload/upload_recipe_step2.dart';
import 'package:hidden_pantry_app/features/recipes/upload/upload_recipe_step3.dart';
import 'package:hidden_pantry_app/features/recipes/upload/upload_recipe_step4.dart';
import 'package:hidden_pantry_app/features/recipes/upload/upload_recipe_step5.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'mock_firebase.dart';
import 'test_utils.dart';

void main() {
  setUpAll(() async {
    setupFirebaseAuthMocks();
    await Firebase.initializeApp();
    setUpNetworkImageMock();
  });

  Widget wrap(Widget child) => MaterialApp(home: child);

  group('Recipe Upload Multi-Step Journey Functional Tests', () {
    testWidgets('Upload Journey: Step 1 Validation (Title & Image)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(const UploadRecipeStep1()));
      await tester.pumpAndSettle();

      // Tap Next without title - check for error or no transition
      await tester.tap(find.byType(GestureDetector).last);
      await tester.pump();
      expect(find.byType(UploadRecipeStep2), findsNothing);

      // Enter Title
      await tester.enterText(find.byType(TextField), 'Rice Pilaf');
      await tester.pump();
      
      // Image is still missing, so it should stay on Step 1
      await tester.tap(find.byType(GestureDetector).last);
      await tester.pump();
      expect(find.byType(UploadRecipeStep2), findsNothing);

      // Wait for toaster to clear
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets('Upload Journey: Step 2 Information (Times & Tags)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(const UploadRecipeStep2(
        title: 'Rice Pilaf',
        image: null,
      )));
      await tester.pumpAndSettle();

      expect(find.text('Information'), findsOneWidget);
      expect(find.text('Preparation Time'), findsOneWidget);
      expect(find.text('Cooking Time'), findsOneWidget);
      
      // Toggle a tag (Cuisine -> Italian)
      await tester.tap(find.text('Cuisine'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Italian'));
      await tester.pumpAndSettle();

      expect(find.text('Next Step'), findsOneWidget);
    });

    testWidgets('Upload Journey: Step 3 Ingredients Entry', (tester) async {
      await tester.pumpWidget(wrap(const UploadRecipeStep3(
        title: 'Rice Pilaf',
        image: null,
        prepTime: 15,
        cookTime: 30,
        servings: 4,
        tags: ['italian'],
      )));
      await tester.pumpAndSettle();

      expect(find.text('Ingredients'), findsOneWidget);
      expect(find.text('Add Ingredients'), findsOneWidget);
      
      // Navigation is manual here, assuming it shows the list.
    });

    testWidgets('Upload Journey: Step 4 Directions Entry', (tester) async {
      await tester.pumpWidget(wrap(const UploadRecipeStep4(
        title: 'Rice Pilaf',
        image: null,
        prepTime: 15,
        cookTime: 30,
        servings: 4,
        tags: ['italian'],
        ingredients: [{'name': 'Rice', 'quantity': '2 cups'}],
      )));
      await tester.pumpAndSettle();

      expect(find.text('Direction'), findsOneWidget);
      expect(find.text('Add Direction'), findsOneWidget);
    });

    testWidgets('Upload Journey: Step 5 Nutrition & Submit', (tester) async {
      await tester.pumpWidget(wrap(UploadRecipeStep5(
        title: 'Rice Pilaf',
        image: null,
        prepTime: 15,
        cookTime: 30,
        servings: 4,
        tags: ['italian'],
        ingredients: const [{'name': 'Rice', 'quantity': '2 cups'}],
        steps: [DirectionStep(id: '1', text: 'Boil it')],
      )));
      await tester.pumpAndSettle();

      expect(find.text('Nutrition'), findsOneWidget);
      expect(find.text('Calories'), findsOneWidget);
      
      // Enter calories
      final calField = find.ancestor(of: find.text('Calories'), matching: find.byType(TextField));
      await tester.enterText(calField, '300');
      await tester.pump();

      expect(find.text('Complete Upload'), findsOneWidget);
    });
  });
}
