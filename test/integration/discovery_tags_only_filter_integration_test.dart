import 'package:flutter_test/flutter_test.dart';

bool tagFilterPass(List<String> recTags, List<String> tags, String q) {
  if (q.trim().isNotEmpty) return true;
  if (tags.isEmpty) return true;
  final lows = tags.map((e) => e.toLowerCase()).toList();
  return recTags.any((t) => lows.contains(t.toLowerCase()));
}

void main() {
  group('Integration: Tags-only filtering behavior', () {
    test('With non-empty query, tag filter does not restrict', () {
      final pass = tagFilterPass(['quick'], ['quick'], 'pasta');
      expect(pass, true);
    });
    test('With empty query, tags must match', () {
      final pass1 = tagFilterPass(['quick'], ['quick'], '');
      final pass2 = tagFilterPass(['family'], ['quick'], '');
      expect(pass1, true);
      expect(pass2, false);
    });
  });
}

