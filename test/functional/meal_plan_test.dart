
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/user/screens/meal_plan_view.dart';
import 'package:hidden_pantry_app/features/recipes/screens/recipe_details.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_service.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:mockito/mockito.dart';
import 'test_utils.dart';

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
  Future<Recipe?> getRecipeById(String id) => super.noSuchMethod(
        Invocation.method(#getRecipeById, [id]),
        returnValue: Future.value(null),
      );
}

void main() {
  setUpAll(() {
    setUpNetworkImageMock();
  });

  final mockPlanData = {
    "title": "Healthy Week",
    "targetCalories": "2000",
    "duration": 7,
    "notes": "Follow this strictly",
    "days": [
      {
        "day": 1,
        "meals": [
          {
            "title": "Oatmeal",
            "type": "BREAKFAST",
            "calories": "300",
            "protein": "10g",
            "carbs": "50g",
            "fats": "5g",
            "imageUrl": "http://example.com/oat.jpg",
            "recipeId": "rec-oat"
          },
          {
            "title": "Grilled Chicken",
            "type": "LUNCH",
            "calories": "500",
            "protein": "40g",
            "carbs": "10g",
            "fats": "20g",
            "imageUrl": "http://example.com/chicken.jpg",
            "recipeId": "rec-chicken"
          },
        ]
      },
      {
        "day": 2,
        "meals": [
          {
            "title": "Smoothie",
            "type": "BREAKFAST",
            "calories": "250",
            "recipeId": "rec-smoothie"
          }
        ]
      }
    ]
  };

  Widget createTestWidget(Widget child) {
    return MaterialApp(
      home: child,
    );
  }

  testWidgets('Meal Plan Flow: View Plan -> Switch Day -> Open Recipe', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockRecipeService = MockRecipeService();
    final mockApiService = MockRecipeApiService();
    
    when(mockRecipeService.incrementRecipeView('rec-smoothie')).thenAnswer((_) async {});
    when(mockRecipeService.isRecipeBookmarked('test-uid', 'rec-smoothie')).thenAnswer((_) async => false);
    when(mockRecipeService.isRecipeLiked('test-uid', 'rec-smoothie')).thenAnswer((_) async => false);
    when(mockRecipeService.getRecipeById('rec-smoothie')).thenAnswer((_) => Future.value(Recipe(
      id: 'rec-smoothie',
      name: 'Smoothie',
      authorId: 'test-author',
      ingredients: [],
      imageUrl: 'http://example.com/smoothie.jpg',
      minutes: 10,
      avgRating: 0.0,
    )));
  
    final smoothieRecipe = Recipe(
      id: 'rec-smoothie',
      name: 'Smoothie',
      authorId: 'test-author',
      ingredients: [],
      imageUrl: 'http://example.com/smoothie.jpg',
      minutes: 10,
      avgRating: 0.0,
    );
    when(mockApiService.getRecipeById('rec-smoothie')).thenAnswer((_) => Future.value(smoothieRecipe));
    when(mockApiService.countRecipesByAuthor('test-author')).thenAnswer((_) => Future.value(0));
    when(mockApiService.fetchRecipesByAuthor('test-author', limit: 12)).thenAnswer((_) => Future.value(<Recipe>[]));
    
    await tester.pumpWidget(createTestWidget(MealPlanViewScreen(
      planData: mockPlanData,
      recipeService: mockRecipeService,
      apiService: mockApiService,
    )));
    await tester.pumpAndSettle();

    // 1. Verify Header and Stats
    expect(find.text('Healthy Week', skipOffstage: false), findsOneWidget);
    expect(find.text('~2000', skipOffstage: false), findsOneWidget); // kcal stat
    expect(find.text('Follow this strictly'), findsOneWidget);

    // 2. Verify Day 1 Meals
    expect(find.text('Oatmeal'), findsOneWidget);
    expect(find.text('Grilled Chicken'), findsOneWidget);

    // 3. Switch to Day 2
    await tester.tap(find.text('Day 2'));
    await tester.pumpAndSettle();

    expect(find.text('Smoothie'), findsOneWidget);
    expect(find.text('Oatmeal'), findsNothing);

    // 4. Open a Recipe from Meal Plan
    await tester.tap(find.text('Smoothie'));
    await tester.pump();                               // let navigation begin
    await tester.pump(const Duration(seconds: 5));     // skip async loads and timers

    // Verify it navigates to RecipeDetailsScreen
    expect(find.byType(RecipeDetailsScreen), findsOneWidget);
    expect(find.text('Smoothie'), findsWidgets); // On details screen
  });
}
