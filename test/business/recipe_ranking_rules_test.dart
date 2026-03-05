import 'package:flutter_test/flutter_test.dart';

class RecipeStub {
  final String name;
  final List<String> ingredients;
  final List<String> tags;
  final String authorName;
  final double avgRating;
  RecipeStub({
    required this.name,
    this.ingredients = const [],
    this.tags = const [],
    this.authorName = '',
    this.avgRating = 0.0,
  });
}

double scoreRecipe({
  required RecipeStub r,
  String query = '',
  List<String> selectedIngredients = const [],
  List<String> selectedTags = const [],
}) {
  double score = 1.0;
  final q = query.toLowerCase().trim();

  if (selectedIngredients.isNotEmpty) {
    final recipeIngs = r.ingredients.map((e) => e.toLowerCase()).toList();
    int matchCount = 0;
    for (final s in selectedIngredients) {
      final lower = s.toLowerCase();
      if (recipeIngs.any((ri) => ri.contains(lower) || lower.contains(ri))) {
        matchCount++;
      }
    }
    score += matchCount * 100;
    if (r.ingredients.isNotEmpty) {
      score += (1.0 / r.ingredients.length) * 50;
    }
  }

  if (selectedTags.isNotEmpty) {
    final recipeTags = r.tags.map((t) => t.toLowerCase()).toList();
    int tagMatchCount = 0;
    for (final t in selectedTags) {
      if (recipeTags.contains(t.toLowerCase())) tagMatchCount++;
    }
    score += tagMatchCount * 50;
  }

  if (q.isNotEmpty) {
    final rName = r.name.toLowerCase();
    if (rName == q) {
      score += 500;
    } else if (rName.startsWith(q)) {
      score += 200;
    } else if (rName.contains(q)) {
      score += 100;
    }
    if (r.ingredients.any((i) => i.toLowerCase().contains(q))) score += 40;
    if (r.tags.any((t) => t.toLowerCase().contains(q))) score += 20;
    if (r.authorName.toLowerCase().contains(q)) score += 30;
  } else {
    score += r.avgRating * 2;
  }

  return score;
}

void main() {
  group('Business: Recipe ranking rules', () {
    test('Exact name > startsWith > contains', () {
      final exact = RecipeStub(name: 'Pizza');
      final starts = RecipeStub(name: 'Pizza Dough');
      final contains = RecipeStub(name: 'Best Pizza Ever');

      final q = 'pizza';
      final sExact = scoreRecipe(r: exact, query: q);
      final sStarts = scoreRecipe(r: starts, query: q);
      final sContains = scoreRecipe(r: contains, query: q);

      expect(sExact, greaterThan(sStarts));
      expect(sStarts, greaterThan(sContains));
    });

    test('Ingredient match boosts and fewer ingredients preferred', () {
      final r1 = RecipeStub(name: 'Salad', ingredients: ['tomato', 'lettuce', 'cucumber']);
      final r2 = RecipeStub(name: 'Tomato Salad', ingredients: ['tomato']);

      final s1 = scoreRecipe(r: r1, selectedIngredients: ['tomato']);
      final s2 = scoreRecipe(r: r2, selectedIngredients: ['tomato']);

      // r2 has same match count but fewer total ingredients so higher
      expect(s2, greaterThan(s1));
    });

    test('Tag and author name matches add bonuses', () {
      final r = RecipeStub(
        name: 'Hearty Soup',
        tags: ['healthy', 'low-fat'],
        authorName: 'Chef Healthy',
      );
      final s = scoreRecipe(r: r, query: 'healthy', selectedTags: ['healthy']);
      // Should include tag match (+50) + tag contains from query (+20) + author name (+30)
      expect(s, greaterThan(1.0 + 50 + 20 + 30 - 0.0001));
    });

    test('When no query, rating influences order', () {
      final low = RecipeStub(name: 'A', avgRating: 2.5);
      final high = RecipeStub(name: 'B', avgRating: 4.5);
      final sLow = scoreRecipe(r: low);
      final sHigh = scoreRecipe(r: high);
      expect(sHigh, greaterThan(sLow));
    });
  });
}

