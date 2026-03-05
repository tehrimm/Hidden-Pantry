import 'package:flutter_test/flutter_test.dart';

class Recipe {
  final String name;
  final List<String> ingredients;
  final List<String> tags;
  Recipe(this.name, this.ingredients, this.tags);
}

List<Recipe> strictIngredients(List<Recipe> recipes, List<String> selected) {
  if (selected.isEmpty) return recipes;
  final lowers = selected.map((e) => e.toLowerCase()).toList();
  return recipes.where((r) {
    final rIngs = r.ingredients.map((e) => e.toLowerCase()).toList();
    for (final s in lowers) {
      final has = rIngs.any((ri) => ri.contains(s) || s.contains(ri));
      if (!has) return false;
    }
    return true;
  }).toList();
}

List<Recipe> applyTagFilterIfNoQuery(List<Recipe> recipes, List<String> tags, String query) {
  if (query.trim().isNotEmpty) return recipes;
  if (tags.isEmpty) return recipes;
  final lows = tags.map((e) => e.toLowerCase()).toList();
  return recipes.where((r) {
    return r.tags.any((t) => lows.contains(t.toLowerCase()));
  }).toList();
}

void main() {
  group('Business: Search filtering rules', () {
    test('Strict ingredient selection requires all selected to be present', () {
      final recipes = [
        Recipe('A', ['tomato', 'basil'], []),
        Recipe('B', ['tomato', 'cheese'], []),
        Recipe('C', ['lettuce'], []),
      ];
      final selected = ['tomato', 'basil'];
      final out = strictIngredients(recipes, selected);
      expect(out.map((r) => r.name), ['A']);
    });

    test('Ingredient substring matching is bidirectional', () {
      final recipes = [
        Recipe('A', ['cherry tomato'], []),
      ];
      final out1 = strictIngredients(recipes, ['tomato']);
      final out2 = strictIngredients(recipes, ['cherry']);
      expect(out1.length, 1);
      expect(out2.length, 1);
    });

    test('With tags and empty query, keep only tag-matching recipes', () {
      final recipes = [
        Recipe('A', [], ['healthy']),
        Recipe('B', [], ['quick']),
        Recipe('C', [], []),
      ];
      final filtered = applyTagFilterIfNoQuery(recipes, ['healthy'], '');
      expect(filtered.map((r) => r.name), ['A']);
    });

    test('With query present, do not drop recipes by tag filter', () {
      final recipes = [
        Recipe('Healthy Soup', ['broth'], []),
        Recipe('Other', [], ['healthy']),
      ];
      final filtered = applyTagFilterIfNoQuery(recipes, ['healthy'], 'soup');
      expect(filtered.map((r) => r.name), ['Healthy Soup', 'Other']);
    });
  });
}

