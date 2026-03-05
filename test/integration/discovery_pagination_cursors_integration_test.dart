import 'package:flutter_test/flutter_test.dart';

class RowItem {
  final String id;
  final double score;
  RowItem(this.id, this.score);
}

class Cursor {
  final double score;
  final String id;
  const Cursor(this.score, this.id);
}

String encode(Cursor c) => '${c.score}|${c.id}';
Cursor decode(String s) {
  final parts = s.split('|');
  return Cursor(double.parse(parts[0]), parts[1]);
}

List<RowItem> paginate({
  required List<RowItem> items, // prescored, unsorted
  String? cursor,
  int limit = 3,
}) {
  // Sort by score desc, tie by id asc
  items.sort((a, b) {
    final c = b.score.compareTo(a.score);
    if (c != 0) return c;
    return a.id.toLowerCase().compareTo(b.id.toLowerCase());
  });
  int start = 0;
  if (cursor != null) {
    final c = decode(cursor);
    start = items.indexWhere((e) => e.score == c.score && e.id == c.id) + 1;
    if (start <= 0) start = 0;
  }
  final end = (start + limit) > items.length ? items.length : (start + limit);
  return items.sublist(start, end);
}

String? nextCursor({
  required List<RowItem> page,
}) {
  if (page.isEmpty) return null;
  final last = page.last;
  return encode(Cursor(last.score, last.id));
}

void main() {
  group('Integration: Discovery pagination cursors', () {
    test('Stable sort, forward-only cursor, consistent pages', () {
      final items = [
        RowItem('a', 10.0),
        RowItem('b', 12.0),
        RowItem('c', 12.0),
        RowItem('d', 5.0),
      ];
      final p1 = paginate(items: List.of(items), cursor: null, limit: 2);
      expect(p1.map((e) => e.id).toList(), ['b', 'c']); // 12.0 b, then 12.0 c by id tie-break
      final c1 = nextCursor(page: p1);
      final p2 = paginate(items: List.of(items), cursor: c1, limit: 2);
      expect(p2.map((e) => e.id).toList(), ['a', 'd']);
      final c2 = nextCursor(page: p2);
      expect(c2, isNotNull);
      final p3 = paginate(items: List.of(items), cursor: c2, limit: 2);
      expect(p3.isEmpty, true);
    });
  });
}

