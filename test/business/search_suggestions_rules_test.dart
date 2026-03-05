import 'package:flutter_test/flutter_test.dart';

List<String> mergeSuggestions({
  required List<String> recent,
  required List<String> popular,
  required int limit,
}) {
  final seen = <String, String>{}; // lower -> canonical
  void addAll(List<String> src) {
    for (final s in src) {
      final key = s.toLowerCase().trim();
      if (key.isEmpty) continue;
      if (!seen.containsKey(key)) {
        seen[key] = s;
      }
      if (seen.length >= limit) break;
    }
  }

  addAll(recent);
  if (seen.length < limit) addAll(popular);

  return seen.values.take(limit).toList();
}

void main() {
  group('Business: Search suggestions rules', () {
    test('Recent prioritized over popular, dedup case-insensitively', () {
      final recent = ['Pizza', 'pasta', 'Salad'];
      final popular = ['pasta', 'sushi', 'pizza', 'burger'];
      final out = mergeSuggestions(recent: recent, popular: popular, limit: 5);
      expect(out, ['Pizza', 'pasta', 'Salad', 'sushi', 'burger']);
    });
    test('Limit enforced', () {
      final recent = ['A', 'B'];
      final popular = ['b', 'C', 'D'];
      final out = mergeSuggestions(recent: recent, popular: popular, limit: 3);
      expect(out, ['A', 'B', 'C']);
    });
    test('Trims and ignores empties', () {
      final out = mergeSuggestions(recent: ['  A ', ''], popular: ['  a '], limit: 2);
      expect(out, ['  A ']);
    });
  });
}

