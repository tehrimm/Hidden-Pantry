import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/features/recipes/screens/cooking_details.dart';
import 'package:hidden_pantry_app/features/recipes/screens/recipe_details.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_api_service.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_service.dart';
import '../functional/mock_firebase.dart';
import '../functional/test_utils.dart';

class _FakeApi extends RecipeApiService {
  const _FakeApi() : super(baseUrl: 'http://localhost');

  @override
  Future<Recipe> getRecipeById(String id) async {
    return _sampleRecipe(id: id);
  }

  @override
  Future<int> countRecipesByAuthor(String authorId) async => 0;

  @override
  Future<List<Recipe>> fetchRecipesByAuthor(String authorId, {int limit = 12}) async => const [];

  @override
  Future<List<Recipe>> searchRecipes(
    String query, {
    int limit = 50,
    List<String>? ingredients,
    int? maxMinutes,
    List<String>? tags,
    List<String>? allergies,
  }) async =>
      const [];
}

class _FakeRecipeService extends RecipeService {
  @override
  Future<void> incrementRecipeView(String recipeId) async {}

  @override
  Future<bool> isRecipeBookmarked(String userId, String recipeId) async => false;

  @override
  Future<bool> isRecipeLiked(String userId, String recipeId) async => false;

  @override
  Future<void> toggleRecipeLike(String userId, String recipeId) async {}

  @override
  Future<Recipe?> getRecipeById(String recipeId) async => null;

  @override
  Future<int> countRecipesByAuthor(String authorId) async => 0;
}

Recipe _sampleRecipe({String id = 'cook-r1'}) => Recipe(
      id: id,
      name: 'Voice Cooking Recipe',
      authorId: 'author-1',
      authorName: 'Chef Test',
      minutes: 20,
      avgRating: 4.4,
      imageUrl: 'http://example.com/recipe.jpg',
      ingredients: const [
        IngredientItem(name: 'Eggs', quantity: 2, unit: 'pcs'),
        IngredientItem(name: 'Salt', quantity: 1, unit: 'tsp'),
      ],
      directions: const [
        'Crack eggs and whisk well.',
        'Cook in a pan until set.',
      ],
      baseServings: 2,
    );

void main() {
  setUpAll(() async {
    setupFirebaseAuthMocks();
    await Firebase.initializeApp();
    setUpNetworkImageMock();
  });

  Widget wrap(Widget child) => MaterialApp(home: child);

  Future<void> _setLargeViewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('Integration: Start Cooking CTA is visible and interactive affordance exists', (tester) async {
    await _setLargeViewport(tester);

    await tester.pumpWidget(
      wrap(
        RecipeDetailsScreen(
          recipe: _sampleRecipe(id: 'r-start'),
          apiService: const _FakeApi(),
          recipeService: _FakeRecipeService(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    final startCooking = find.text('Start Cooking');
    expect(startCooking, findsOneWidget);
    expect(
      find.ancestor(of: startCooking, matching: find.byType(GestureDetector)),
      findsWidgets,
    );
  });

  testWidgets('Integration: Cooking details shows play voice control', (tester) async {
    await _setLargeViewport(tester);

    await tester.pumpWidget(
      wrap(CookingDetailsScreen(recipe: _sampleRecipe(id: 'r-play'), initialServings: 2)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('PLAY'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });

  testWidgets('Integration: Ingredients entry opens ingredient drawer', (tester) async {
    await _setLargeViewport(tester);

    await tester.pumpWidget(
      wrap(CookingDetailsScreen(recipe: _sampleRecipe(id: 'r-ings'), initialServings: 2)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    await tester.tap(find.text('Ingredients'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('Ingredients for 2 servings'), findsOneWidget);
  });

  testWidgets('Integration: Cooking details shows first step context', (tester) async {
    await _setLargeViewport(tester);

    await tester.pumpWidget(
      wrap(CookingDetailsScreen(recipe: _sampleRecipe(id: 'r-step'), initialServings: 2)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Step 1 of 2'), findsOneWidget);

    expect(find.textContaining('Crack eggs and whisk'), findsOneWidget);
  });

  testWidgets('Integration: Ingredient drawer lists key ingredients', (tester) async {
    await _setLargeViewport(tester);

    await tester.pumpWidget(
      wrap(CookingDetailsScreen(recipe: _sampleRecipe(id: 'r-finish'), initialServings: 2)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    await tester.tap(find.text('Ingredients'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Eggs'), findsWidgets);
    expect(find.text('Salt'), findsOneWidget);
  });
}
