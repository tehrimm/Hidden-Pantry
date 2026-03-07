import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/features/recipes/widgets/recipe_card.dart';

void main() {
  testWidgets('Recipes folder: RecipeCard renders basic info', (WidgetTester tester) async {
    final recipe = Recipe(
      id: 'r1',
      name: 'Test Recipe',
      minutes: 25,
      avgRating: 4.2,
      imageUrl: null,
      ingredients: const [
        IngredientItem(name: 'Tomato', quantity: 2.0, unit: 'pcs'),
      ],
      directions: const ['Cut', 'Cook'],
      baseServings: 2,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecipeCard(
            recipe: recipe,
            onTap: () {},
            width: 250,
          ),
        ),
      ),
    );

    expect(find.text('Test Recipe'), findsOneWidget);
    expect(find.textContaining('min'), findsOneWidget);
  });
}

