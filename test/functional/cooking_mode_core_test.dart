import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/features/recipes/screens/cooking_details.dart';
import 'mock_firebase.dart';
import 'test_utils.dart';

void main() {
  setUpAll(() async {
    setupFirebaseAuthMocks();
    await Firebase.initializeApp();
    setUpNetworkImageMock();
  });

  Widget wrap(Widget child) => MaterialApp(home: child);

  Recipe sampleRecipe() => const Recipe(
        id: 'cook-r1',
        name: 'Functional Cooking Test',
        authorId: 'author-1',
        authorName: 'Chef Test',
        minutes: 20,
        avgRating: 4.2,
        imageUrl: 'http://example.com/recipe.jpg',
        ingredients: [
          IngredientItem(name: 'Eggs', quantity: 2, unit: 'pcs'),
          IngredientItem(name: 'Salt', quantity: 1, unit: 'tsp'),
        ],
        directions: [
          'Crack eggs and whisk.',
          'Cook in pan for 2 minutes.',
        ],
        baseServings: 2,
      );

  testWidgets('Cooking mode shows current step and ingredients entrypoint', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      wrap(CookingDetailsScreen(recipe: sampleRecipe(), initialServings: 2)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Step 1 of 2'), findsOneWidget);
    expect(find.text('Ingredients'), findsOneWidget);
    expect(find.textContaining('Crack eggs'), findsOneWidget);
  });
}
