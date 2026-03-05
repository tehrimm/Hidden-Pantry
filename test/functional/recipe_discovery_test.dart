
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:hidden_pantry_app/features/recipes/screens/search/search.dart';
import 'package:hidden_pantry_app/features/recipes/screens/recipe_details.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'test_utils.dart';
import 'mock_firebase.dart';

// Mocks
// Using MockRecipeApiService from test_utils.dart
class MockRecipeService extends Mock implements RecipeService {
  @override
  Future<void> incrementRecipeView(String id) => super.noSuchMethod(
        Invocation.method(#incrementRecipeView, [id]),
        returnValue: Future.value(),
      );

  @override
  Future<bool> isRecipeBookmarked(String userId, String recipeId) => super.noSuchMethod(
        Invocation.method(#isRecipeBookmarked, [userId, recipeId]),
        returnValue: Future.value(false),
      );

  @override
  Future<bool> isRecipeLiked(String userId, String recipeId) => super.noSuchMethod(
        Invocation.method(#isRecipeLiked, [userId, recipeId]),
        returnValue: Future.value(false),
      );

  @override
  Future<Recipe> getRecipeById(String id) => super.noSuchMethod(
        Invocation.method(#getRecipeById, [id]),
        returnValue: Future.value(Recipe(
          id: id,
          name: '',
          description: '',
          imageUrl: '',
          minutes: 0,
          avgRating: 0.0,
          ingredients: [],
          directions: [],
          tags: [],
          authorId: '',
          authorName: '',
        )),
      );
}
class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockUser extends Mock implements User {}

void main() {
  late MockRecipeApiService mockApi;
  late MockRecipeService mockRecipeService;

  setUpAll(() async {
    setUpNetworkImageMock();
    setupFirebaseAuthMocks();
    await Firebase.initializeApp();
  });

  setUp(() {
    mockApi = MockRecipeApiService();
    mockRecipeService = MockRecipeService();
  });

  Widget createTestWidget(Widget child) {
    return MaterialApp(
      home: child,
    );
  }

  final testRecipe = Recipe(
    id: 'recipe-1',
    name: 'Test Spaghetti',
    imageUrl: 'http://example.com/spaghetti.jpg',
    minutes: 30,
    prepMinutes: 10,
    cookMinutes: 20,
    avgRating: 4.5,
    baseServings: 2,
    ingredients: [
      IngredientItem(name: 'Pasta', quantity: 200, unit: 'g'),
      IngredientItem(name: 'Tomato Sauce', quantity: 1, unit: 'cup'),
    ],
    directions: ['Cook pasta', 'Add sauce'],
    tags: ['Italian', 'Pasta'],
    authorId: 'author-1',
    authorName: 'Chef Test',
  );

  testWidgets('Recipe Discovery: Search -> View Details', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // 1. Search Screen
    when(mockApi.searchRecipes(
      'spaghetti', 
      limit: 50,
      ingredients: anyNamed('ingredients'),
      maxMinutes: anyNamed('maxMinutes'),
      tags: anyNamed('tags'),
    )).thenAnswer((_) async => [testRecipe]);

    await tester.pumpWidget(createTestWidget(SearchScreen(apiService: mockApi)));

    // Verify initial state
    expect(find.byType(TextField), findsOneWidget);

    // Enter search query
    await tester.enterText(find.byType(TextField), 'spaghetti');
    await tester.pump(const Duration(milliseconds: 500)); // Account for debounce
    await tester.pumpAndSettle();

    // Verify result appears
    expect(find.text('Test Spaghetti'), findsOneWidget);

    // 2. Open Recipe Details
    // Mocking further calls inside RecipeDetailsScreen
    when(mockApi.getRecipeById('recipe-1')).thenAnswer((_) => Future.value(testRecipe));
    when(mockApi.countRecipesByAuthor('author-1')).thenAnswer((_) => Future.value(1));
    when(mockApi.fetchRecipesByAuthor('author-1', limit: 12)).thenAnswer((_) => Future.value(<Recipe>[]));
    when(mockRecipeService.incrementRecipeView('recipe-1')).thenAnswer((_) => Future.value());
    when(mockRecipeService.isRecipeBookmarked('test-uid', 'recipe-1')).thenAnswer((_) => Future.value(false));
    when(mockRecipeService.isRecipeLiked('test-uid', 'recipe-1')).thenAnswer((_) => Future.value(false));
    when(mockRecipeService.getRecipeById('recipe-1')).thenAnswer((_) => Future.value(testRecipe));
    when(mockApi.searchRecipes('Chef Test', limit: 12)).thenAnswer((_) => Future.value(<Recipe>[]));

    await tester.tap(find.text('Test Spaghetti'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4)); // Fast-forward past Firestore fallback timer leakage

    // Verify on Details Screen
    expect(find.byType(RecipeDetailsScreen), findsOneWidget);
    expect(find.text('Test Spaghetti'), findsOneWidget); 
    expect(find.text('Chef Test'), findsOneWidget);
    expect(find.text('200 g'), findsOneWidget); // Quantity check
    expect(find.text('Pasta'), findsOneWidget);
  });
}
