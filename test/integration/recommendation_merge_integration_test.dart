import 'package:flutter_test/flutter_test.dart';

class Item {
  final String id;
  final String source; // 'follow' or 'recommend'
  final double score;
  Item(this.id, this.source, this.score);
}

List<Item> mergeRecommendations({
  required List<Item> follow,
  required List<Item> recommend,
  int limit = 10,
}) {
  // Follow has priority. Dedup by id (case-insensitive). Within same source, order by score desc, tie by id asc.
  int cmp(Item a, Item b) {
    final c = b.score.compareTo(a.score);
    if (c != 0) return c;
    return a.id.toLowerCase().compareTo(b.id.toLowerCase());
  }
  follow.sort(cmp);
  recommend.sort(cmp);
  final seen = <String>{};
  final out = <Item>[];
  void sub(List pipeline) {
    for (final i in pipeline) {
      final key = (i as Item).id.toLowerCase();
      if (seen.add(key)) {
        out.add(i);
        if (out.length >= limit) break;
      }
    }
  }
  sub(follow);
  if (out.length < limit) sub(recommend);
  return out.take(limit).toList();
}

void main() {
  group('Integration: Recommendation merge with dedup priorities', () {
    test('Prioritizes follow, dedups ids, stable tie-breaks', () {
      final follow = [
        Item('r1', 'follow', 0.8),
        Item('r3', 'follow', 0.9),
      ];
      final reco = [
        Item('r2', 'recommend', 0.95),
        Item('R1', 'recommend', 0.99), // duplicate id, different case
      ];
      final out = mergeRecommendations(follow: follow, recommend: reco, limit: 3);
      // r3 (0.9 follow) first, then r1 (follow beats reco duplicate), then r2
      expect(out.map((i) => i.id).toList(), ['r3', 'r1', 'r2']);
    });
  });
}

