import 'package:flutter_test/flutter_test.dart';

class FeedItem {
  final String id;
  final String authorId;
  final DateTime time;
  final int likes;
  final int minTier;
  FeedItem(this.id, this.authorId, this.time, this.likes, this.minTier);
}

double score(FeedItem i, DateTime now) {
  final ageHours = now.difference(i.time).inHours;
  final recency = ageHours <= 0 ? 1000.0 : 1000.0 / (ageHours + 1);
  return i.likes * 5 + recency;
}

List<FeedItem> rankFeed({
  required List<FeedItem> items,
  required Set<String> following,
  required Set<String> blocked,
  required int userTier,
  required DateTime now,
  int limit = 10,
}) {
  final filtered = items.where((i) =>
      following.contains(i.authorId) &&
      !blocked.contains(i.authorId.toLowerCase()) &&
      userTier >= i.minTier);
  final scored = filtered
      .map((i) => MapEntry(i, score(i, now)))
      .toList();
  scored.sort((a, b) => b.value.compareTo(a.value));
  final out = <FeedItem>[];
  for (final e in scored) {
    out.add(e.key);
    if (out.length >= limit) break;
  }
  return out;
}

void main() {
  group('Integration: Feed ranking with recency + engagement', () {
    test('Orders by composite score after filtering follow/blocked/tier', () {
      final now = DateTime(2026, 1, 10, 12, 0);
      final items = [
        FeedItem('f1', 'a1', now.subtract(const Duration(hours: 1)), 20, 0),
        FeedItem('f2', 'a2', now.subtract(const Duration(hours: 10)), 200, 0),
        FeedItem('f3', 'a3', now.subtract(const Duration(minutes: 30)), 5, 1),
      ];
      final out = rankFeed(
        items: items,
        following: {'a1', 'a2', 'a3'}.toSet(),
        blocked: {'a3'}.toSet(),
        userTier: 0,
        now: now,
      );
      expect(out.map((e) => e.id).toList().first, 'f2');
      expect(out.any((e) => e.id == 'f3'), false);
    });
  });
}
