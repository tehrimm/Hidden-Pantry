import 'package:flutter_test/flutter_test.dart';

bool shouldSearch({
  required String query,
  required List<String> tags,
  required List<String> ingredients,
  int minLen = 2,
}) {
  final q = query.trim();
  if (q.isEmpty) return tags.isNotEmpty || ingredients.isNotEmpty;
  return q.length >= minLen;
}

void main() {
  group('Business: Minimum query length rules', () {
    test('Empty query allowed if tags or ingredients present', () {
      expect(shouldSearch(query: '', tags: ['t'], ingredients: []), true);
      expect(shouldSearch(query: '', tags: [], ingredients: ['ing']), true);
      expect(shouldSearch(query: '', tags: [], ingredients: []), false);
    });
    test('Short query below min length blocked', () {
      expect(shouldSearch(query: 'a', tags: [], ingredients: []), false);
    });
    test('Query at or above min length allowed', () {
      expect(shouldSearch(query: 'ab', tags: [], ingredients: []), true);
      expect(shouldSearch(query: 'abc', tags: [], ingredients: []), true);
    });
  });
}

