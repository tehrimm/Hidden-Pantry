import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_api_service.dart';
import 'package:hidden_pantry_app/features/recipes/screens/search/search.dart';
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

  group('Search screen repeated interactions set 2', () {
    final queries = [
      'gg','hh','ii','jj','kk','ll','mm','nn','oo','pp',
      'qq','rr','ss1','tt1','uu1','vv1','ww1','xx1','yy1','zz1',
      'alfa','beta','gamma','delta','omega',
      'food1','food2','meal1','meal2','meal3'
    ];

    for (final q in queries) {
      testWidgets('Search query $q shows empty results (set2)', (tester) async {
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
}
