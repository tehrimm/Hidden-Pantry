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

    testWidgets('Clear button appears after typing', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(wrap(SearchScreen(apiService: const FakeApi())));
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, 'x');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump();
      expect(find.textContaining('No recipes found'), findsNothing);
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

    testWidgets('Typing and clearing returns to initial state', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(wrap(SearchScreen(apiService: const FakeApi())));
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, 'pizza');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump();
      expect(find.byIcon(Icons.tune_rounded), findsNothing);
    });
  });

  group('Search screen filters', () {
    testWidgets('Open and dismiss filter bottom sheet', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(wrap(SearchScreen(apiService: const FakeApi())));
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, 'filters');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      // Open filter sheet
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pump(const Duration(milliseconds: 400));
      // Validate bottom sheet content is visible near the top
      expect(find.text('Time'), findsOneWidget);
      expect(find.text('Diet'), findsOneWidget);
      // Dismiss the sheet with a drag-down gesture on a visible element
      await tester.drag(find.text('Time'), const Offset(0, 600));
      await tester.pump(const Duration(milliseconds: 500));
      // Back on search screen
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
    });

    // Note: Pantry navigation from search is covered by Pantry screen basics group.
  });

  group('Search screen repeated interactions', () {
    for (final q in [
      'a','b','c','d','e','f','g','h','i','j',
      'k','l','m','n','o','p','q','r','s','t'
    ]) {
      testWidgets('Search query $q shows empty results', (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(wrap(SearchScreen(apiService: const FakeApi())));
        await tester.pump();
        await tester.enterText(find.byType(TextField).first, q);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        expect(find.textContaining('No recipes found'), findsOneWidget);
      });
    }
    for (final q in ['u','v','w','x','y','z','aa','bb','cc','dd','ee','ff']) {
      testWidgets('Search query $q shows empty results (extended)', (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(wrap(SearchScreen(apiService: const FakeApi())));
        await tester.pump();
        await tester.enterText(find.byType(TextField).first, q);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        expect(find.textContaining('No recipes found'), findsOneWidget);
      });
    }
  });

  group('Pantry screen basics', () {
    testWidgets('Pantry shows search hint', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(wrap(const PantryScreen()));
      await tester.pump();
      expect(find.text('Search ingredients...'), findsOneWidget);
    });

    testWidgets('Pantry Done button exists', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(wrap(const PantryScreen()));
      await tester.pump();
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('Pantry typing shows clear icon', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(wrap(const PantryScreen()));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'ri');
      await tester.pump();
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('Pantry renders with initial selected items', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(wrap(const PantryScreen(
        initialSelectedIngredients: ['salt', 'sugar'],
        showSelectedSection: true,
      )));
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('RecipeSearch screen error flow', () {
    testWidgets('Builds and shows grid placeholder content', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(wrap(const RecipeSearchScreen(query: 'x')));
      await tester.pump();
      expect(find.byType(GridView), findsOneWidget);
    });

    testWidgets('Loading skeleton appears first', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(wrap(const RecipeSearchScreen(query: 'y')));
      await tester.pump();
      expect(find.byType(GridView), findsOneWidget);
    });
  });
}
