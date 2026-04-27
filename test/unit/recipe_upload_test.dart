import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_service.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/core/services/view_mode_service.dart';
import 'package:firebase_core/firebase_core.dart';
import '../functional/mock_firebase.dart';

void main() {
  group('Recipe Upload Process Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuth mockAuth;
    late RecipeService recipeService;

    setUpAll(() async {
      setupFirebaseAuthMocks();
      await Firebase.initializeApp();
    });

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuth = MockFirebaseAuth(signedIn: true);
      recipeService = RecipeService(
        firestore: fakeFirestore,
        auth: mockAuth,
        viewMode: MockViewModeService(isNutr: false),
      );
    });

    test('uploadFullRecipe should create a new document in Firestore', () async {
      final recipeData = {
        'title': 'Test Pasta',
        'prepTime': 10,
        'cookTime': 20,
        'servings': 4,
        'difficulty': 'Easy',
        'tags': ['Italian', 'Quick'],
        'ingredients': [{'name': 'Flour', 'quantity': '500g'}],
        'steps': [DirectionStep(id: 's1', text: 'Mix it', imageUrl: null)],
        'nutrition': {'Calories': '300'},
      };

      await recipeService.uploadFullRecipe(
        title: recipeData['title'] as String,
        mainImage: null,
        ingredients: recipeData['ingredients'] as List<Map<String, dynamic>>,
        prepTime: recipeData['prepTime'] as int,
        cookTime: recipeData['cookTime'] as int,
        servings: recipeData['servings'] as int,
        difficulty: recipeData['difficulty'] as String,
        tags: recipeData['tags'] as List<String>,
        steps: recipeData['steps'] as List<DirectionStep>,
        nutrition: recipeData['nutrition'] as Map<String, String>,
        isPublic: true,
      );

      final snapshot = await fakeFirestore.collection('recipes').get();
      expect(snapshot.docs.length, 1);
      expect(snapshot.docs.first.data()['name'], 'Test Pasta');
      expect(snapshot.docs.first.data()['is_public'], true);
    });

    test('uploadFullRecipe correctly parses ingredient quantities', () async {
      await recipeService.uploadFullRecipe(
        title: 'Ing Test',
        mainImage: null,
        ingredients: [{'name': 'Milk', 'quantity': '1.5 cups'}],
        prepTime: 5,
        cookTime: 5,
        servings: 1,
        difficulty: 'Easy',
        tags: [],
        steps: [DirectionStep(id: 's2', text: 'Drink', imageUrl: null)],
        nutrition: {},
      );

      final doc = (await fakeFirestore.collection('recipes').get()).docs.first;
      final parsed = doc.data()['ingredients_parsed'] as List;
      expect(parsed.first['quantity'], 1.5);
      expect(parsed.first['unit'], 'cups');
    });

    test('uploadFullRecipe increments user recipe_count for new uploads', () async {
      final uid = mockAuth.currentUser!.uid;
      // Pre-seed user doc
      await fakeFirestore.collection('users').doc(uid).set({'recipe_count': 0});

      await recipeService.uploadFullRecipe(
        title: 'Count Test',
        mainImage: null,
        ingredients: [],
        prepTime: 5,
        cookTime: 5,
        servings: 1,
        difficulty: 'Easy',
        tags: [],
        steps: [],
        nutrition: {},
      );

      final userDoc = await fakeFirestore.collection('users').doc(uid).get();
      expect(userDoc.data()?['recipe_count'], 1);
    });

    test('uploadFullRecipe prevents upload if user is not logged in', () async {
      final loggedOutService = RecipeService(
        firestore: fakeFirestore,
        auth: MockFirebaseAuth(signedIn: false),
      );

      expect(
        () => loggedOutService.uploadFullRecipe(
          title: 'Fail',
          mainImage: null,
          ingredients: [],
          prepTime: 0,
          cookTime: 0,
          servings: 0,
          difficulty: '',
          tags: [],
          steps: [],
          nutrition: {},
        ),
        throwsException,
      );
    });

    test('uploadFullRecipe correctly sums prep and cook time into minutes', () async {
      await recipeService.uploadFullRecipe(
        title: 'Time Test',
        mainImage: null,
        ingredients: [],
        prepTime: 15,
        cookTime: 45,
        servings: 1,
        difficulty: 'Medium',
        tags: [],
        steps: [],
        nutrition: {},
      );

      final doc = (await fakeFirestore.collection('recipes').get()).docs.first;
      expect(doc.data()['minutes'], 60);
    });

    test('uploadFullRecipe preserves nutritionist flag if view mode is nutritionist', () async {
      // Mock ViewModeService to return true
      final mockViewMode = MockViewModeService(isNutr: true);
      final nutrRecipeService = RecipeService(
        firestore: fakeFirestore,
        auth: mockAuth,
        viewMode: mockViewMode,
      );

      await nutrRecipeService.uploadFullRecipe(
        title: 'Nutr Recipe',
        mainImage: null,
        ingredients: [],
        prepTime: 10,
        cookTime: 10,
        servings: 1,
        difficulty: 'Easy',
        tags: [],
        steps: [],
        nutrition: {},
      );

      final doc = (await fakeFirestore.collection('recipes').get()).docs.first;
      expect(doc.data()['is_nutritionist_recipe'], true);
    });

    test('uploadFullRecipe updates existing document if recipeId is provided', () async {
      final existingId = 'old_recipe';
      await fakeFirestore.collection('recipes').doc(existingId).set({'name': 'Old Name'});

      await recipeService.uploadFullRecipe(
        recipeId: existingId,
        title: 'New Name',
        mainImage: null,
        ingredients: [],
        prepTime: 5,
        cookTime: 5,
        servings: 1,
        difficulty: 'Easy',
        tags: [],
        steps: [],
        nutrition: {},
      );

      final doc = await fakeFirestore.collection('recipes').doc(existingId).get();
      expect(doc.data()?['name'], 'New Name');
      final totalDocs = await fakeFirestore.collection('recipes').get();
      expect(totalDocs.docs.length, 1); // No new doc created
    });

    test('uploadFullRecipe correctly stores difficulty and tags', () async {
      await recipeService.uploadFullRecipe(
        title: 'Meta Test',
        mainImage: null,
        ingredients: [],
        prepTime: 1,
        cookTime: 1,
        servings: 1,
        difficulty: 'Hard',
        tags: ['Vegan', 'Gluten-Free'],
        steps: [],
        nutrition: {},
      );

      final doc = (await fakeFirestore.collection('recipes').get()).docs.first;
      expect(doc.data()['difficulty'], 'Hard');
      expect(doc.data()['tags'], containsAll(['Vegan', 'Gluten-Free']));
    });

    test('uploadFullRecipe stores servings and base_servings correctly', () async {
      await recipeService.uploadFullRecipe(
        title: 'Servings Test',
        mainImage: null,
        ingredients: [],
        prepTime: 1,
        cookTime: 1,
        servings: 6,
        difficulty: 'Easy',
        tags: [],
        steps: [],
        nutrition: {},
      );

      final doc = (await fakeFirestore.collection('recipes').get()).docs.first;
      expect(doc.data()['servings'], 6);
      expect(doc.data()['base_servings'], 6);
    });

    test('uploadFullRecipe maps author metadata from current user', () async {
      await recipeService.uploadFullRecipe(
        title: 'Author Test',
        mainImage: null,
        ingredients: [],
        prepTime: 1,
        cookTime: 1,
        servings: 1,
        difficulty: 'Easy',
        tags: [],
        steps: [],
        nutrition: {},
      );

      final doc = (await fakeFirestore.collection('recipes').get()).docs.first;
      expect(doc.data()['author_id'], mockAuth.currentUser!.uid);
      expect(doc.data()['author_name'], isNotNull);
    });
  });
}

class MockViewModeService implements ViewModeService {
  final bool isNutr;
  MockViewModeService({required this.isNutr});
  
  @override
  Future<bool> isNutritionist() async => isNutr;

  @override
  Future<void> init() async {}

  @override
  Future<bool> isInUserView() async => false;

  @override
  Future<void> setUserView(bool enabled) async {}

  @override
  void clearCache() {}

  @override
  Future<void> resetToNutritionistView() async {}
}
