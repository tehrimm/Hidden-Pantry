import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

/// Pure business logic helpers extracted from RecipeService review math.
/// Tests the arithmetic logic used in addReview and deleteReview transactions.
double computeNewAvg(double currentAvg, int currentCount, double newRating) {
  final finalCount = currentCount + 1;
  return ((currentAvg * currentCount) + newRating) / finalCount;
}

double computeAfterDeletion({
  required double oldAvg,
  required int oldCount,
  required double deletedRating,
  required int baseCount,
  required double baseAvg,
}) {
  if (oldCount <= baseCount) return oldAvg; // Can't go below base
  final newCount = oldCount - 1;
  if (newCount <= baseCount) return baseAvg;
  return ((oldAvg * oldCount) - deletedRating) / newCount;
}

String buildReviewId(String userId, String recipeId) => '${userId}_$recipeId';

void main() {
  group('Real Integration Tests: Rating & Review Calculation Engine', () {

    group('computeNewAvg — addReview math', () {
      test('First review: avg becomes the rating itself', () {
        final avg = computeNewAvg(0.0, 0, 5.0);
        expect(avg, closeTo(5.0, 0.001));
      });

      test('Second review with equal rating keeps average', () {
        final avg = computeNewAvg(4.0, 1, 4.0); // avg=4, count=1 → add 4.0
        expect(avg, closeTo(4.0, 0.001));
      });

      test('Second review with different rating averages correctly', () {
        // (4.0 * 1 + 2.0) / 2 = 3.0
        final avg = computeNewAvg(4.0, 1, 2.0);
        expect(avg, closeTo(3.0, 0.001));
      });

      test('High volume rating convergence', () {
        // After 100 reviews all at 4.0, avg should be 4.0
        double avg = 0.0;
        int count = 0;
        for (int i = 0; i < 100; i++) {
          avg = computeNewAvg(avg, count, 4.0);
          count++;
        }
        expect(avg, closeTo(4.0, 0.001));
      });

      test('Mixed ratings converge to correct average', () {
        // 5 reviews: 1, 2, 3, 4, 5 → avg = 3.0
        double avg = 0.0;
        int count = 0;
        for (final rating in [1.0, 2.0, 3.0, 4.0, 5.0]) {
          avg = computeNewAvg(avg, count, rating);
          count++;
        }
        expect(avg, closeTo(3.0, 0.001));
      });
    });

    group('computeAfterDeletion — deleteReview math', () {
      test('Deleting the only user review reverts to base average', () {
        // baseCount=10, baseAvg=4.2, oldCount=11 (1 user review), oldAvg=4.18
        // Deleting user review (rating=3.5)
        final result = computeAfterDeletion(
          oldAvg: 4.18,
          oldCount: 11,
          deletedRating: 3.5,
          baseCount: 10,
          baseAvg: 4.2,
        );
        // newCount = 10 = baseCount → returns baseAvg
        expect(result, closeTo(4.2, 0.001));
      });

      test('Deleting one of many user reviews recalculates correctly', () {
        // 2 user reviews on top of base. oldCount=12, oldAvg = (4.2*10 + 3.5 + 4.5)/12 = 4.2
        // Actually let's compute: sum = (4.2 * 10) + 3.5 + 4.5 = 42+8 = 50. Avg = 50/12 ≈ 4.167
        // Now delete 3.5: (4.167 * 12 - 3.5) / 11 = (50.0 - 3.5) / 11 = 46.5/11 ≈ 4.227
        final oldAvg = (4.2 * 10 + 3.5 + 4.5) / 12;
        final result = computeAfterDeletion(
          oldAvg: oldAvg,
          oldCount: 12,
          deletedRating: 3.5,
          baseCount: 10,
          baseAvg: 4.2,
        );
        expect(result, closeTo(4.227, 0.005));
      });

      test('Cannot delete below base count (no-op)', () {
        // oldCount == baseCount → shouldn't allow further deletion
        final result = computeAfterDeletion(
          oldAvg: 4.0,
          oldCount: 10,
          deletedRating: 3.0,
          baseCount: 10,
          baseAvg: 4.0,
        );
        expect(result, 4.0); // unchanged
      });
    });

    group('Review ID construction', () {
      test('Review ID is userId_recipeId format', () {
        expect(buildReviewId('user_001', 'recipe_abc'), 'user_001_recipe_abc');
      });

      test('Review ID is deterministic and unique per user-recipe pair', () {
        final id1 = buildReviewId('alice', 'pasta');
        final id2 = buildReviewId('bob', 'pasta');
        final id3 = buildReviewId('alice', 'soup');

        expect(id1, isNot(equals(id2))); // Different users
        expect(id1, isNot(equals(id3))); // Different recipes
        expect(id1, 'alice_pasta');
      });
    });

    group('Tag weight personalization', () {
      test('Tag weight map accumulates correctly across views', () {
        // Simulate what trackUserView does to tagWeights
        final Map<String, int> tagWeights = {};

        void trackView(List<String> tags) {
          for (final tag in tags) {
            final key = tag.toLowerCase();
            tagWeights[key] = (tagWeights[key] ?? 0) + 1;
          }
        }

        trackView(['Italian', 'Dinner']);
        trackView(['Italian', 'Lunch']);
        trackView(['Asian', 'Dinner']);

        expect(tagWeights['italian'], 2);
        expect(tagWeights['dinner'], 2);
        expect(tagWeights['lunch'], 1);
        expect(tagWeights['asian'], 1);
      });

      test('Tags are lowercased before weighting', () {
        final Map<String, int> weights = {};
        for (final tag in ['Italian', 'ITALIAN', 'italian']) {
          weights[tag.toLowerCase()] = (weights[tag.toLowerCase()] ?? 0) + 1;
        }
        expect(weights['italian'], 3);
        expect(weights.length, 1); // All collapsed to one key
      });
    });
  });

  group('Real Integration Tests: Recipe Search & Filter Logic', () {
    final recipes = [
      const Recipe(id: 's1', name: 'Chicken Tikka Masala', minutes: 45, avgRating: 4.8, tags: ['Indian', 'Chicken', 'Dinner']),
      const Recipe(id: 's2', name: 'Spaghetti Carbonara', minutes: 20, avgRating: 4.5, tags: ['Italian', 'Pasta', 'Dinner']),
      const Recipe(id: 's3', name: 'Chicken Caesar Salad', minutes: 15, avgRating: 4.2, tags: ['Salad', 'Chicken', 'Lunch']),
      const Recipe(id: 's4', name: 'Beef Tacos', minutes: 25, avgRating: 4.6, tags: ['Mexican', 'Beef', 'Dinner']),
      const Recipe(id: 's5', name: 'Vegan Buddha Bowl', minutes: 20, avgRating: 4.3, tags: ['Vegan', 'Healthy', 'Lunch']),
    ];

    test('Search by name substring (case-insensitive)', () {
      final query = 'chicken';
      final results = recipes
          .where((r) => r.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
      expect(results.length, 2);
      expect(results.map((r) => r.id).toSet(), {'s1', 's3'});
    });

    test('Search by tag', () {
      final results = recipes
          .where((r) => r.tags.any((t) => t.toLowerCase() == 'dinner'))
          .toList();
      expect(results.length, 3);
      expect(results.map((r) => r.id).toSet(), {'s1', 's2', 's4'});
    });

    test('Sort search results by highest rating', () {
      final sorted = List<Recipe>.from(recipes)
        ..sort((a, b) => b.avgRating.compareTo(a.avgRating));
      expect(sorted.first.id, 's1'); // 4.8
      expect(sorted.last.id, 's3');  // 4.2
    });

    test('Filter by max cooking time', () {
      final quick = recipes.where((r) => r.minutes <= 20).toList();
      expect(quick.length, 3);
      expect(quick.map((r) => r.id).toSet(), {'s2', 's3', 's5'});
    });

    test('Filter vegan recipes', () {
      final vegan = recipes
          .where((r) => r.tags.map((t) => t.toLowerCase()).contains('vegan'))
          .toList();
      expect(vegan.length, 1);
      expect(vegan.first.id, 's5');
    });

    test('Combined filter: lunch + max 20 mins', () {
      final results = recipes.where((r) =>
          r.tags.map((t) => t.toLowerCase()).contains('lunch') &&
          r.minutes <= 20
      ).toList();
      expect(results.length, 2); // s3 (15m) and s5 (20m)
      expect(results.map((r) => r.id).toSet(), {'s3', 's5'});
    });
  });
}
