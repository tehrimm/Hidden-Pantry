import 'package:flutter_test/flutter_test.dart';

class Item {
  final String id;
  final int page;
  Item(this.id, this.page);
}

class PageCursor {
  final int page;
  final String? lastId; // for tie-breaks if needed
  const PageCursor(this.page, this.lastId);
}

List<Item> accumulatePages({
  required List<List<Item>> pages,
  required int limit,
}) {
  final seen = <String>{};
  final out = <Item>[];
  for (final page in pages) {
    for (final it in page) {
      if (seen.contains(it.id.toLowerCase())) continue;
      seen.add(it.id.toLowerCase());
      out.add(it);
      if (out.length >= limit) return out;
    }
  }
  return out;
}

PageCursor nextCursor(PageCursor current) => PageCursor(current.page + 1, null);

void main() {
  group('Business: Discovery pagination rules', () {
    test('Accumulates pages up to limit, deduping by id', () {
      final pages = [
        [Item('a', 1), Item('b', 1)],
        [Item('b', 2), Item('c', 2), Item('d', 2)],
      ];
      final out = accumulatePages(pages: pages, limit: 3);
      expect(out.map((i) => i.id), ['a', 'b', 'c']);
    });
    test('Cursor advances page-by-page', () {
      final c0 = PageCursor(1, null);
      final c1 = nextCursor(c0);
      final c2 = nextCursor(c1);
      expect(c1.page, 2);
      expect(c2.page, 3);
    });
  });
}

