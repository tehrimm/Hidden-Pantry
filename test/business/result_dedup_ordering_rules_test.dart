import 'package:flutter_test/flutter_test.dart';

class Item {
  final String id;
  final double score;
  final String name;
  Item(this.id, this.score, this.name);
}

List<Item> sortByScoreThenName(List<Item> items) {
  final next = [...items];
  next.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return next;
}

List<Item> dedupStable(List<Item> sources) {
  final seen = <String, Item>{};
  for (final it in sources) {
    final key = it.id.toLowerCase();
    if (!seen.containsKey(key)) {
      seen[key] = it;
    }
  }
  return seen.values.toList();
}

void main() {
  group('Business: Result dedup and ordering', () {
    test('Stable dedup by id (case-insensitive)', () {
      final src = [
        Item('A', 0.1, 'alpha'),
        Item('b', 0.2, 'beta'),
        Item('a', 0.3, 'alpha 2'),
      ];
      final out = dedupStable(src);
      expect(out.length, 2);
      expect(out.map((i) => i.id), ['A', 'b']);
    });

    test('Order by score desc then name asc', () {
      final items = [
        Item('a', 1.0, 'Pizza'),
        Item('b', 2.0, 'Burger'),
        Item('c', 2.0, 'Apple'),
      ];
      final out = sortByScoreThenName(items);
      expect(out.map((i) => i.id), ['c', 'b', 'a']);
    });

    test('Combined: sort then dedup keeps best ordering with first occurrence win', () {
      final items = [
        Item('x', 1.0, 'Zed'),
        Item('X', 2.0, 'Alpha'),
        Item('y', 3.0, 'Bee'),
      ];
      final sorted = sortByScoreThenName(items);
      final deduped = dedupStable(sorted);
      expect(deduped.map((i) => i.id.toLowerCase()), ['y', 'x']);
    });
  });
}

