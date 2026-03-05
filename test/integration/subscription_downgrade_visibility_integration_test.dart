import 'package:flutter_test/flutter_test.dart';

List<String> visibleAfterDowngrade({
  required List<Map<String, dynamic>> items, // [{'id':..., 'minTier':...}]
  required int newTier,
}) {
  return items
      .where((m) => newTier >= (m['minTier'] as int))
      .map((m) => m['id'] as String)
      .toList();
}

void main() {
  group('Integration: Subscription downgrade visibility', () {
    test('Higher-tier-only items become hidden after downgrade', () {
      final items = [
        {'id': 'c1', 'minTier': 0},
        {'id': 'c2', 'minTier': 1},
        {'id': 'c3', 'minTier': 2},
      ];
      final pre = visibleAfterDowngrade(items: items, newTier: 2);
      expect(pre, ['c1', 'c2', 'c3']);
      final post = visibleAfterDowngrade(items: items, newTier: 0);
      expect(post, ['c1']);
    });
  });
}

