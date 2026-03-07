import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hidden_pantry_app/features/recipes/screens/search/search.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_api_service.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'mock_firebase.dart';

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
    return [];
  }
}

void main() {
  setUpAll(() async {
    setupFirebaseAuthMocks();
    await Firebase.initializeApp();
  });

  Widget wrap(Widget child) => MaterialApp(home: child);

  testWidgets('Search suggestion updates query when tapped', (WidgetTester tester) async {
    final api = FakeApi();

    await tester.pumpWidget(wrap(SearchScreen(apiService: api)));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'piza');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.textContaining('Did you mean:'), findsOneWidget);
    expect(find.text('"pizza"'), findsOneWidget);

    await tester.tap(find.text('"pizza"'));
    await tester.pump();

    final tf = tester.widget<TextField>(find.byType(TextField));
    expect(tf.controller?.text, 'pizza');
  });
}
