import 'package:flutter_test/flutter_test.dart';

class Item {
  final String id;
  final double score;
  Item(this.id, this.score);
}

List<Item> sortStable(List<Item> items) {
  items.sort((a, b) {
    final c = b.score.compareTo(a.score);
    if (c != 0) return c;
    return a.id.toLowerCase().compareTo(b.id.toLowerCase());
  });
  return items;
}

void main() {
  group('Integration: Discovery stable tiebreak ordering', () {
    test('Equal scores sort by id ascending', () {
      final items = [
        Item('b', 10),
        Item('a', 10),
        Item('c', 12),
      ];
      final out = sortStable(items);
      expect(out.map((i) => i.id).toList(), ['c', 'a', 'b']);
    });
  });
}

