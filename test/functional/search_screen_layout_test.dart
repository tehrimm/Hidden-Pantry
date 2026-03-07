import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hidden_pantry_app/features/recipes/screens/search/search.dart';
import 'mock_firebase.dart';
import 'test_utils.dart';

import 'package:hidden_pantry_app/features/recipes/services/recipe_api_service.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

class FakeApi extends RecipeApiService {
  const FakeApi() : super(baseUrl: 'http://localhost');
  @override
  Future<List<Recipe>> searchRecipes(
    String query, {
    int limit = 50,
    List<String>? ingredients,
    int? maxMinutes,
    List<String>? tags,
    List<String>? allergies,
  }) async {
    return <Recipe>[];
  }
}

void main() {
  setUpAll(() async {
    setupFirebaseAuthMocks();
    await Firebase.initializeApp();
    setUpNetworkImageMock();
  });

  Widget wrap(Widget child) => MaterialApp(home: child);

  testWidgets('SearchScreen shows text field on standard phone size', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(SearchScreen(apiService: const FakeApi(), inShell: true)));
    await tester.pump();

    // Ensure search field exists and is visible
    expect(find.byType(TextField), findsOneWidget);
  });
}

