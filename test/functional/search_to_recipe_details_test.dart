import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_api_service.dart';
import 'package:hidden_pantry_app/features/recipes/screens/search/search.dart';
import 'package:hidden_pantry_app/features/recipes/screens/recipe_details.dart';
import 'test_utils.dart';
import 'mock_firebase.dart';

class FakeApiWithResults extends RecipeApiService {
  const FakeApiWithResults() : super(baseUrl: 'http://localhost');
  @override
  Future<List<Recipe>> searchRecipes(
    String query, {
    int limit = 50,
    List<String>? ingredients,
    int? maxMinutes,
    List<String>? tags,
  }) async {
    return [
      Recipe(
        id: 'id1',
        name: 'Pizza One',
        minutes: 15,
        avgRating: 4.0,
        authorId: 'a1',
        authorName: 'Chef A',
        ingredients: const [],
        directions: const ['Step'],
        tags: const [],
      ),
      Recipe(
        id: 'id2',
        name: 'Pizza Two',
        minutes: 20,
        avgRating: 4.2,
        authorId: 'a2',
        authorName: 'Chef B',
        ingredients: const [],
        directions: const ['Step'],
        tags: const [],
      ),
    ];
  }
}

void main() {
  setUpAll(() async {
    setupFirebaseAuthMocks();
    await Firebase.initializeApp();
    setUpNetworkImageMock();
  });

  Widget wrap(Widget child) => MaterialApp(home: child);

  testWidgets('Search results tap navigates to Recipe Details', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(SearchScreen(apiService: const FakeApiWithResults())));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'pizza');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.text('Pizza One'), findsOneWidget);
    expect(find.text('Pizza Two'), findsOneWidget);

    await tester.tap(find.text('Pizza One'));
    await tester.pumpAndSettle();

    expect(find.byType(RecipeDetailsScreen), findsOneWidget);
    expect(find.text('Start Cooking'), findsOneWidget);
  });
}
