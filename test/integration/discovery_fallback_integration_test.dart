import 'package:flutter_test/flutter_test.dart';

class RecipeItem {
  final String id;
  final String name;
  final List<String> ingredients;
  final double rating;
  RecipeItem(this.id, this.name, this.ingredients, this.rating);
}

bool hasAllSelected(List<String> rec, List<String> selected) {
  if (selected.isEmpty) return true;
  final r = rec.map((e) => e.toLowerCase()).toList();
  for (final s in selected.map((e) => e.toLowerCase())) {
    final ok = r.any((ri) => ri.contains(s) || s.contains(ri));
    if (!ok) return false;
  }
  return true;
}

double scoreByQuery(RecipeItem r, String q) {
  final query = q.toLowerCase().trim();
  if (query.isEmpty) return r.rating;
  double s = 0;
  final name = r.name.toLowerCase();
  if (name == query) s += 5;
  else if (name.startsWith(query)) s += 3;
  else if (name.contains(query)) s += 1;
  if (r.ingredients.any((i) => i.toLowerCase().contains(query))) s += 0.5;
  s += r.rating * 0.1;
  return s;
}

List<RecipeItem> searchRecipes({
  required List<RecipeItem> pool,
  required String query,
  required List<String> ingredients,
  required bool fallbackEnabled,
  int limit = 5,
}) {
  // First pass: strict ingredients filter
  var first = pool.where((r) => hasAllSelected(r.ingredients, ingredients)).toList();
  if (first.isEmpty && fallbackEnabled) {
    // Fallback: ignore ingredients, rank by query/rating
    final scored = pool
        .map((r) => MapEntry(r, scoreByQuery(r, query)))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return scored.map((e) => e.key).take(limit).toList();
  }
  // Normal ranking on first-pass set
  first.sort((a, b) => b.rating.compareTo(a.rating));
  if (first.length > limit) first = first.sublist(0, limit);
  return first;
}

void main() {
  group('Integration: Discovery fallback when strict filters empty', () {
    test('Returns strict matches when found', () {
      final pool = [
        RecipeItem('r1', 'Pasta Red', ['pasta', 'tomato'], 4.5),
        RecipeItem('r2', 'Rice Bowl', ['rice'], 4.9),
      ];
      final out = searchRecipes(
        pool: pool,
        query: 'pasta',
        ingredients: ['tomato'],
        fallbackEnabled: true,
      );
      expect(out.map((r) => r.id).toList(), ['r1']);
    });

    test('Falls back to query/rating when strict yields empty', () {
      final pool = [
        RecipeItem('r1', 'Pasta Red', ['pasta', 'tomato'], 4.5),
        RecipeItem('r2', 'Rice Bowl', ['rice'], 4.9),
      ];
      final out = searchRecipes(
        pool: pool,
        query: 'rice',
        ingredients: ['beef'], // impossible strict
        fallbackEnabled: true,
      );
      expect(out.first.id, 'r2');
    });
  });
}
