import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/features/recipes/screens/recipe_details.dart';
import 'test_utils.dart';
import 'mock_firebase.dart';

void main() {
  setUpAll(() async {
    setupFirebaseAuthMocks();
    await Firebase.initializeApp();
    setUpNetworkImageMock();
  });

  Widget wrap(Widget child) => MaterialApp(home: child);

  testWidgets('Recipe Details: shows loading skeleton initially', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final recipe = Recipe(
      id: 'r1',
      name: 'Test Dish',
      authorId: 'a1',
      authorName: 'Chef',
      imageUrl: 'http://example.com/img.jpg',
      minutes: 20,
      avgRating: 0.0,
      baseServings: 2,
      ingredients: [
        IngredientItem(name: 'Item', quantity: 1, unit: 'pc'),
      ],
      directions: ['Do A', 'Do B'],
    );

    await tester.pumpWidget(wrap(RecipeDetailsScreen(recipe: recipe)));
    await tester.pump();
    expect(find.text('Loading Recipe...'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}
