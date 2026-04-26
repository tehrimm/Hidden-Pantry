import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/screens/reviews/reviews.dart';
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

  testWidgets('ReviewsScreen displays empty state when no reviews exist', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Create a dummy recipe
    final dummyRecipe = Recipe(
      id: 'r1',
      name: 'Spaghetti Bolognese',
      minutes: 45,
      avgRating: 0.0,
      reviewCount: 0,
      ingredients: [],
      directions: [],
    );

    await tester.pumpWidget(wrap(ReviewsScreen(recipe: dummyRecipe, recipeService: MockRecipeService())));
    await tester.pump(const Duration(seconds: 1));

    // Verify header text
    expect(find.text('Tips & Photos'), findsOneWidget);
    expect(find.text('Spaghetti Bolognese'), findsOneWidget);

    // Verify empty state is displayed because the mock stream has no data
    expect(find.byType(Icon), findsWidgets);
    expect(find.text('No reviews yet.'), findsOneWidget);
    expect(find.text('Be the first to share your thoughts!'), findsOneWidget);
  });
}
