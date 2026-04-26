import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_api_service.dart';
import 'package:hidden_pantry_app/features/recipes/screens/search/search.dart';
import 'package:hidden_pantry_app/features/recipes/screens/search/pantry_screen.dart';
import 'package:hidden_pantry_app/features/recipes/screens/search/recipe_search.dart';
import 'test_utils.dart';
import 'mock_firebase.dart';

class FakeApi extends RecipeApiService {
  const FakeApi() : super(baseUrl: 'http://localhost');
  @override
  Future<List<Recipe>> recommend({
    String? query,
    List<String> ingredients = const [],
    String? tag,
    List<String> allergies = const [],
    List<String> likedRecipeIds = const [],
    int? maxMinutes,
    double? minRating,
    int topK = 10,
  }) async {
    return [];
  }

  @override
  Future<List<Recipe>> searchRecipes(
    String query, {
    int limit = 50,
    List<String>? ingredients,
    int? maxMinutes,
    List<String>? tags,
    List<String>? allergies,
  }) async {
    return [];
  }
}

void main() {
  setUpAll(() async {
    setupFirebaseAuthMocks();
    await Firebase.initializeApp();
    setUpNetworkImageMock();
  });

  Widget wrap(Widget child) => MaterialApp(home: child);

  group('Search screen basic flows', () {
    testWidgets('Search initial shows pantry icon', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(wrap(SearchScreen(apiService: const FakeApi())));
      await tester.pump();
      expect(find.byIcon(Icons.tune_rounded), findsNothing);
    });

    testWidgets('Typing with no results shows empty message', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(wrap(SearchScreen(apiService: const FakeApi())));
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, 'abc');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.textContaining('No recipes found'), findsOneWidget);
    });

    testWidgets('Filter icon shows after searching', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(wrap(SearchScreen(apiService: const FakeApi())));
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, 'filter');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
    });
  });
}
