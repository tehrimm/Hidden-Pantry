import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hidden_pantry_app/features/recipes/screens/recipe_details.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'test_utils.dart';
import 'mock_firebase.dart';

void main() {
  setUpAll(() async {
    setupFirebaseAuthMocks();
    await Firebase.initializeApp();
    setUpNetworkImageMock();
  });

  Widget wrap(Widget child) => MaterialApp(home: child);

  final mockRecipe = Recipe(
    id: 'r1',
    name: 'Test Recipe',
    minutes: 30,
    avgRating: 4.5,
    authorId: 'a1',
    authorName: 'Test Author',
    ingredients: [],
    directions: ['Step 1'],
  );

  group('Recipe Details screen tests', () {
    testWidgets('Recipe details renders basic info', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(RecipeDetailsScreen(recipe: mockRecipe)));
      await tester.pump();
      
      expect(find.text('Test Recipe'), findsWidgets);
      expect(find.text('Test Author'), findsOneWidget);

      // Clear timers from StaggeredEntry
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('Recipe details shows action buttons', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(RecipeDetailsScreen(recipe: mockRecipe)));
      await tester.pump();
      
      // Favorite button
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      // Bookmark button
      expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
      
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
