import 'package:flutter_test/flutter_test.dart';

class Recipe {
  final String id;
  final String name;
  final List<String> ingredients;
  final List<String> tags;
  final String authorId;
  final double rating;
  final int minTier;
  Recipe({
    required this.id,
    required this.name,
    required this.ingredients,
    required this.tags,
    required this.authorId,
    required this.rating,
    this.minTier = 0,
  });
}

// Strict ingredients
bool hasAllSelected(List<String> rec, List<String> selected) {
  if (selected.isEmpty) return true;
  final r = rec.map((e) => e.toLowerCase()).toList();
  for (final s in selected.map((e) => e.toLowerCase())) {
    final ok = r.any((ri) => ri.contains(s) || s.contains(ri));
    if (!ok) return false;
  }
  return true;
}

// Tag filter only when no query text
bool tagFilterPass(List<String> recTags, List<String> tags, String q) {
  if (q.trim().isNotEmpty) return true;
  if (tags.isEmpty) return true;
  final lows = tags.map((e) => e.toLowerCase()).toList();
  return recTags.any((t) => lows.contains(t.toLowerCase()));
}

// Content gating
bool canView(int userTier, int minTier) => userTier >= minTier;

// Score like in service
double scoreRecipe(Recipe r, String query, List<String> ings, List<String> tags) {
  double score = 1.0;
  final q = query.toLowerCase().trim();
  if (ings.isNotEmpty) {
    final rec = r.ingredients.map((e) => e.toLowerCase()).toList();
    int matches = 0;
    for (final s in ings.map((e) => e.toLowerCase())) {
      if (rec.any((ri) => ri.contains(s) || s.contains(ri))) matches++;
    }
    score += matches * 100;
    if (r.ingredients.isNotEmpty) score += (1.0 / r.ingredients.length) * 50;
  }
  if (tags.isNotEmpty) {
    final rec = r.tags.map((e) => e.toLowerCase()).toList();
    int t = 0;
    for (final s in tags.map((e) => e.toLowerCase())) {
      if (rec.contains(s)) t++;
    }
    score += t * 50;
  }
  if (q.isNotEmpty) {
    final name = r.name.toLowerCase();
    if (name == q) score += 500;
    else if (name.startsWith(q)) score += 200;
    else if (name.contains(q)) score += 100;
    if (r.ingredients.any((i) => i.toLowerCase().contains(q))) score += 40;
    if (r.tags.any((t) => t.toLowerCase().contains(q))) score += 20;
  } else {
    score += r.rating * 2;
  }
  return score;
}

List<Recipe> discover({
  required List<Recipe> pool,
  required String query,
  required List<String> ingredients,
  required List<String> tags,
  required List<String> followedAuthors,
  required List<String> blockedAuthors,
  required int userTier,
  int limit = 10,
}) {
  final blocked = blockedAuthors.map((e) => e.toLowerCase()).toSet();
  final followed = followedAuthors.toSet();
  var filtered = pool.where((r) =>
      followed.contains(r.authorId) &&
      !blocked.contains(r.authorId.toLowerCase()) &&
      canView(userTier, r.minTier) &&
      hasAllSelected(r.ingredients, ingredients) &&
      tagFilterPass(r.tags, tags, query));
  final scored = filtered
      .map((r) => MapEntry(r, scoreRecipe(r, query, ingredients, tags)))
      .toList();
  scored.sort((a, b) => b.value.compareTo(a.value));
  final dedup = <String, Recipe>{};
  for (final e in scored) {
    final key = e.key.id.toLowerCase();
    dedup.putIfAbsent(key, () => e.key);
    if (dedup.length >= limit) break;
  }
  return dedup.values.toList();
}

void main() {
  group('Integration: Discovery end-to-end', () {
    test('Applies followed, blocked, gating, strict ings, tag-only, scoring, limit', () {
      final pool = [
        Recipe(
          id: 'r1',
          name: 'Tomato Pasta',
          ingredients: ['tomato', 'pasta', 'salt'],
          tags: ['quick'],
          authorId: 'a1',
          rating: 4.5,
          minTier: 0,
        ),
        Recipe(
          id: 'r2',
          name: 'Gold Tomato Soup',
          ingredients: ['tomato', 'water'],
          tags: ['healthy'],
          authorId: 'a2',
          rating: 4.9,
          minTier: 2,
        ),
        Recipe(
          id: 'r3',
          name: 'Pasta Deluxe',
          ingredients: ['pasta', 'cream', 'salt'],
          tags: ['family'],
          authorId: 'a3',
          rating: 4.0,
          minTier: 0,
        ),
      ];
      final out = discover(
        pool: pool,
        query: 'pasta',
        ingredients: ['tomato'], // strict
        tags: ['quick'], // tag-only ignored since query is present
        followedAuthors: ['a1', 'a2', 'a3'],
        blockedAuthors: ['a3'],
        userTier: 1, // cannot view minTier 2
        limit: 5,
      );
      // r2 gated by tier, r3 blocked, r1 remains and satisfies strict ingredients
      expect(out.map((r) => r.id), ['r1']);
    });
  });
}

