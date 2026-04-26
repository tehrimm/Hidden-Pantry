import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/utils/recipe_matcher.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/features/user/services/subscription_service.dart';

void main() {
  group('Real Integration Tests: Cooking Mode & Voice Feature Pipeline', () {
    late SubscriptionService subscriptionService;
    Map<String, dynamic>? mockUserData;
    List<Map<String, dynamic>> mockPlatformSubs = [];
    DateTime mockNow = DateTime(2026, 4, 1);

    final mockAuth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'cook_uid'));

    // Sample recipe pool representing the cooking session
    const spicyRamen = Recipe(
      id: 'cook_1',
      name: 'Spicy Ramen',
      minutes: 25,
      avgRating: 4.6,
      ingredients: [
        IngredientItem(name: 'ramen noodles', quantity: 1, unit: 'pack'),
        IngredientItem(name: 'chicken', quantity: 200, unit: 'g'),  // weight 1.5
        IngredientItem(name: 'soy sauce', quantity: 2, unit: 'tbsp'),
        IngredientItem(name: 'sriracha', quantity: 1, unit: 'tsp'), // spicy!
      ],
      baseServings: 1,
    );

    const safeOmelette = Recipe(
      id: 'cook_2',
      name: 'Simple Omelette',
      minutes: 10,
      avgRating: 5.0,
      ingredients: [
        IngredientItem(name: 'egg', quantity: 3, unit: 'pcs', calories: 70),
        IngredientItem(name: 'butter', quantity: 1, unit: 'tbsp', calories: 102),
        IngredientItem(name: 'salt', quantity: 1, unit: 'pinch'), // weight 0.1
      ],
      baseServings: 1,
    );

    const salmonDinner = Recipe(
      id: 'cook_3',
      name: 'Pan Salmon',
      minutes: 20,
      avgRating: 4.9,
      ingredients: [
        IngredientItem(name: 'salmon', quantity: 1, unit: 'fillet'), // weight 2.0
        IngredientItem(name: 'garlic', quantity: 3, unit: 'cloves'), // weight 0.8
        IngredientItem(name: 'butter', quantity: 1, unit: 'tbsp'),   // dairy!
      ],
      baseServings: 1,
    );

    setUp(() {
      mockPlatformSubs = [];
      mockUserData = {
        'isPremium': false,
        'createdAt': mockNow.subtract(const Duration(days: 20)), // Past trial
        'downloadedRecipeIds': [],
      };

      subscriptionService = SubscriptionService.injectable(
        auth: mockAuth,
        now: () => mockNow,
        loadUserData: (uid) async => mockUserData,
        loadPlatformSubscriptions: (uid) async => mockPlatformSubs,
        loadNutritionistSubscriptions: (uid, nutId) async => [],
        appendDownloadedRecipeId: (uid, recipeId) async {},
      );
    });

    test('Free user cannot start voice cooking mode', () async {
      final canUseVoice = await subscriptionService.canUseFeature('voice_cooking');
      expect(canUseVoice, false);
    });

    test('Premium user can start voice cooking mode', () async {
      mockPlatformSubs = [{'expiryDate': mockNow.add(const Duration(days: 30))}];
      final canUseVoice = await subscriptionService.canUseFeature('voice_cooking');
      expect(canUseVoice, true);
    });

    test('Pantry matching finds best recipe from pool', () {
      // User has salmon and garlic in pantry
      final pantry = ['salmon', 'garlic', 'butter'];
      final sorted = RecipeMatcher.sortRecipesByMatch(
        [spicyRamen, safeOmelette, salmonDinner],
        pantry,
      );
      // salmonDinner has all 3 ingredients → highest match
      expect(sorted.first.id, 'cook_3');
    });

    test('Allergy filter removes unsafe recipes before cooking session starts', () {
      // User has spicy and dairy allergy
      final pantry = ['salmon', 'garlic', 'butter', 'ramen noodles', 'chicken', 'egg', 'salt'];
      final sorted = RecipeMatcher.sortRecipesByMatch(
        [spicyRamen, safeOmelette, salmonDinner],
        pantry,
        allergies: ['spicy', 'dairy'],
      );
      // spicyRamen contains sriracha (spicy) → score 0
      // salmonDinner contains butter (dairy) → score 0
      // safeOmelette: egg + salt only (no dairy/spicy allergens matched) → non-zero
      expect(sorted.first.id, 'cook_2'); // safeOmelette is the only safe one
    });

    test('Scaling ingredients for 2 servings in cooking mode', () {
      // Start cooking with 2 servings
      final scaled = safeOmelette.getScaledIngredients(2);
      expect(scaled[0].name, 'egg');
      expect(scaled[0].quantity, 6.0);   // 3 * 2
      expect(scaled[0].calories, 140.0); // 70 * 2
      expect(scaled[1].quantity, 2.0);   // 1 * 2
      expect(scaled[1].calories, 204.0); // 102 * 2
    });

    test('Scaling to 0 servings defaults multiplier to 1.0', () {
      final scaled = safeOmelette.getScaledIngredients(0);
      expect(scaled[0].quantity, 3.0); // unchanged
    });

    test('Calculating total calories during cooking', () {
      // safeOmelette has no nutrition map → sum ingredients
      // egg: 70, butter: 102, salt: null → 172
      expect(safeOmelette.calculatedTotalCalories, closeTo(172.0, 0.01));
    });

    test('Prep/cook time split for cooking mode timer', () {
      // spicyRamen: 25 mins. >= 20 so: prep=15, cook=10
      expect(spicyRamen.prepMinutes, 15);
      expect(spicyRamen.cookMinutes, 10);

      // safeOmelette: 10 mins. < 20 so: prep=10, cook=0
      expect(safeOmelette.prepMinutes, 10);
      expect(safeOmelette.cookMinutes, 0);
    });
  });
}
