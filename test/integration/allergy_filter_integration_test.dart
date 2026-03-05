import 'package:flutter_test/flutter_test.dart';

class Recipe {
  final String id;
  final List<String> ingredients;
  final List<String> allergens;
  Recipe(this.id, this.ingredients, this.allergens);
}

bool passesAllergy(List<String> allergens, List<String> userAllergies) {
  if (userAllergies.isEmpty) return true;
  final set = userAllergies.map((e) => e.toLowerCase()).toSet();
  for (final a in allergens) {
    if (set.contains(a.toLowerCase())) return false;
  }
  return true;
}

List<Recipe> discoveryWithAllergy({
  required List<Recipe> pool,
  required List<String> userAllergies,
}) {
  return pool.where((r) => passesAllergy(r.allergens, userAllergies)).toList();
}

void main() {
  group('Integration: Allergy filtering in discovery', () {
    test('Excludes any recipe that contains a user allergen', () {
      final pool = [
        Recipe('r1', ['tomato', 'pasta'], ['gluten']),
        Recipe('r2', ['rice', 'veg'], []),
        Recipe('r3', ['bread'], ['GlUtEn']),
      ];
      final out = discoveryWithAllergy(pool: pool, userAllergies: ['gluten']);
      expect(out.map((r) => r.id).toList(), ['r2']);
    });
  });
}

