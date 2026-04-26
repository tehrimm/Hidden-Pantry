import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/utils/recipe_matcher.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/features/user/models/user_model.dart';

void main() {
  group('Real Integration Tests: User Allergies → Recipe Filtering Pipeline', () {
    // Recipe pool
    const cheesePasta = Recipe(
      id: 'ap_1', name: 'Cheese Pasta',
      minutes: 20, avgRating: 4.3,
      ingredients: [
        IngredientItem(name: 'pasta', quantity: 200, unit: 'g'),
        IngredientItem(name: 'parmesan cheese', quantity: 50, unit: 'g'), // dairy
      ],
    );

    const veganSalad = Recipe(
      id: 'ap_2', name: 'Vegan Salad',
      minutes: 10, avgRating: 4.8,
      ingredients: [
        IngredientItem(name: 'spinach', quantity: 100, unit: 'g'),
        IngredientItem(name: 'tomato', quantity: 2, unit: 'pcs'),
        IngredientItem(name: 'olive oil', quantity: 1, unit: 'tbsp'),
      ],
    );

    const peanutSauce = Recipe(
      id: 'ap_3', name: 'Peanut Sauce Noodles',
      minutes: 15, avgRating: 4.5,
      ingredients: [
        IngredientItem(name: 'peanut butter', quantity: 3, unit: 'tbsp'),
        IngredientItem(name: 'noodles', quantity: 200, unit: 'g'),
        IngredientItem(name: 'soy sauce', quantity: 1, unit: 'tbsp'),
      ],
    );

    const shrimpStir = Recipe(
      id: 'ap_4', name: 'Shrimp Stir Fry',
      minutes: 20, avgRating: 4.7,
      ingredients: [
        IngredientItem(name: 'shrimp', quantity: 200, unit: 'g'), // shellfish
        IngredientItem(name: 'garlic', quantity: 3, unit: 'cloves'),
        IngredientItem(name: 'soy sauce', quantity: 2, unit: 'tbsp'),
      ],
    );

    final allRecipes = [cheesePasta, veganSalad, peanutSauce, shrimpStir];

    test('UserModel.allergies drives RecipeMatcher.isSafe correctly', () {
      final user = UserModel(
        uid: 'u1', email: 'alice@test.com', fullName: 'Alice',
        role: 'homecook',
        allergies: ['dairy', 'peanut'],
      );

      final safeRecipes = allRecipes
          .where((r) => RecipeMatcher.isSafe(r, user.allergies))
          .toList();

      // cheesePasta (dairy) → blocked
      // peanutSauce (peanut) → blocked
      // veganSalad → safe
      // shrimpStir → safe (no dairy or peanut)
      expect(safeRecipes.length, 2);
      expect(safeRecipes.map((r) => r.id).contains('ap_2'), true); // veganSalad
      expect(safeRecipes.map((r) => r.id).contains('ap_4'), true); // shrimpStir
    });

    test('Shellfish allergy blocks shrimp recipes', () {
      final user = UserModel(
        uid: 'u2', email: 'bob@test.com', fullName: 'Bob',
        role: 'homecook',
        allergies: ['shellfish'],
      );

      final safeRecipes = allRecipes
          .where((r) => RecipeMatcher.isSafe(r, user.allergies))
          .toList();

      expect(safeRecipes.map((r) => r.id).contains('ap_4'), false); // shrimpStir blocked
      expect(safeRecipes.length, 3);
    });

    test('User with no allergies gets all recipes', () {
      final user = UserModel(
        uid: 'u3', email: 'carol@test.com', fullName: 'Carol',
        role: 'homecook',
        allergies: [],
      );

      final safeRecipes = allRecipes
          .where((r) => RecipeMatcher.isSafe(r, user.allergies))
          .toList();

      expect(safeRecipes.length, 4);
    });

    test('UserModel.copyWith updated allergies changes safe recipe pool', () {
      final user = UserModel(
        uid: 'u4', email: 'dan@test.com', fullName: 'Dan',
        role: 'homecook', allergies: [],
      );

      // Before adding allergy — all safe
      final beforeCount = allRecipes
          .where((r) => RecipeMatcher.isSafe(r, user.allergies))
          .length;
      expect(beforeCount, 4);

      // After adding dairy allergy — cheese pasta blocked
      final updatedUser = user.copyWith(allergies: ['dairy']);
      final afterCount = allRecipes
          .where((r) => RecipeMatcher.isSafe(r, updatedUser.allergies))
          .length;
      expect(afterCount, 3);
    });

    test('sortRecipesByMatch ranks vegan salad with full pantry match highest', () {
      // Pantry exactly matches veganSalad (no high-weight ingredients)
      final pantry = ['spinach', 'tomato', 'olive oil'];
      final sorted = RecipeMatcher.sortRecipesByMatch(allRecipes, pantry);
      expect(sorted.first.id, 'ap_2');
    });

    test('Combined allergy + pantry produces correct ranked safe list', () {
      final user = UserModel(
        uid: 'u5', email: 'eve@test.com', fullName: 'Eve',
        role: 'homecook', allergies: ['shellfish', 'peanut'],
      );

      final pantry = ['spinach', 'tomato', 'olive oil', 'pasta', 'parmesan cheese'];
      final sorted = RecipeMatcher.sortRecipesByMatch(
        allRecipes,
        pantry,
        allergies: user.allergies,
      );

      // shrimpStir (shellfish) → 0
      // peanutSauce (peanut) → 0
      // cheesePasta (parmesan in pantry) → partial match
      // veganSalad (spinach,tomato,olive oil in pantry) → full match
      expect(sorted.first.id, 'ap_2'); // veganSalad full match
    });
  });
}
