import 'package:flutter_test/flutter_test.dart';

class Recipe {
  final String id;
  final List<String> ingredients;
  const Recipe(this.id, this.ingredients);
}

bool containsAllergen(List<String> recipeIngs, List<String> allergens) {
  final r = recipeIngs.map((e) => e.toLowerCase()).toList();
  final a = allergens.map((e) => e.toLowerCase()).toList();
  for (final al in a) {
    for (final ing in r) {
      if (ing.contains(al) || al.contains(ing)) return true;
    }
  }
  return false;
}

List<Recipe> filterAllergens(List<Recipe> recipes, List<String> allergens) {
  if (allergens.isEmpty) return recipes;
  return recipes.where((rec) => !containsAllergen(rec.ingredients, allergens)).toList();
}

void main() {
  group('Business: Allergy filtering rules', () {
    test('No allergens returns all recipes', () {
      final rs = [Recipe('r1', ['milk']), Recipe('r2', ['peanut'])];
      final out = filterAllergens(rs, const []);
      expect(out.length, 2);
    });
    test('Filters recipes containing allergens', () {
      final rs = [
        Recipe('r1', ['milk', 'flour']),
        Recipe('r2', ['peanut butter', 'salt']),
        Recipe('r3', ['almond milk']),
      ];
      final out = filterAllergens(rs, ['peanut', 'almond']);
      expect(out.map((r) => r.id), ['r1']);
    });
    test('Bidirectional substring catch (e.g., "nut" vs "peanut")', () {
      final rs = [
        Recipe('r1', ['pea']),
        Recipe('r2', ['peanut']),
      ];
      final out = filterAllergens(rs, ['nut']);
      expect(out.map((r) => r.id), ['r1']);
    });
  });
}

