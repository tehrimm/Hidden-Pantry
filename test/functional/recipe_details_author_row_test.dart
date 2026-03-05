import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_api_service.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_service.dart';
import 'package:hidden_pantry_app/features/recipes/screens/recipe_details.dart';
import 'test_utils.dart';
import 'mock_firebase.dart';

class FakeApi extends RecipeApiService {
  const FakeApi() : super(baseUrl: 'http://localhost');
  @override
  Future<Recipe> getRecipeById(String id) async {
    return Recipe(
      id: id,
      name: 'Essential Test Recipe',
      minutes: 30,
      avgRating: 4.5,
      authorId: 'author-1',
      authorName: 'Chef Test',
      baseServings: 1,
      ingredients: const [
        IngredientItem(name: 'Flour', quantity: 200, unit: 'g'),
      ],
      directions: const ['Mix', 'Bake'],
      tags: const ['test'],
    );
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
  }) async =>
      const [];
}

class FakeRecipeService extends RecipeService {
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

void main() {
  setUpAll(() async {
    setupFirebaseAuthMocks();
    await Firebase.initializeApp();
    setUpNetworkImageMock();
  });

  Widget wrap(Widget child) => MaterialApp(home: child);

  Recipe sampleRecipe() => const Recipe(
        id: 'r1',
        name: 'Essential Test Recipe',
        minutes: 30,
        avgRating: 4.2,
        authorId: 'author-1',
        authorName: 'Chef Test',
        baseServings: 1,
        ingredients: [IngredientItem(name: 'Sugar', quantity: 100, unit: 'g')],
        directions: ['Step 1', 'Step 2'],
        tags: ['t'],
      );

  testWidgets('RecipeDetails: author row shows author name', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(RecipeDetailsScreen(
      recipe: sampleRecipe(),
      apiService: const FakeApi(),
      recipeService: FakeRecipeService(),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Chef Test'), findsOneWidget);
  });
}
