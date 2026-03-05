import 'package:flutter_test/flutter_test.dart';

class Recipe {
  final String id;
  final String authorId;
  Recipe(this.id, this.authorId);
}

List<Recipe> followingFeed({
  required List<Recipe> all,
  required List<String> authorIds,
  int limit = 20,
}) {
  if (authorIds.isEmpty) return [];
  final allowed = authorIds.toSet();
  final filtered = all.where((r) => allowed.contains(r.authorId)).toList();
  if (filtered.length <= limit) return filtered;
  return filtered.sublist(0, limit);
}

void main() {
  group('Business: Following feed rules', () {
    test('Empty authors list yields empty feed', () {
      final out = followingFeed(all: [Recipe('r1', 'a1')], authorIds: []);
      expect(out, isEmpty);
    });
    test('Includes only followed authors', () {
      final all = [
        Recipe('r1', 'a1'),
        Recipe('r2', 'a2'),
        Recipe('r3', 'a3'),
      ];
      final out = followingFeed(all: all, authorIds: ['a1', 'a3']);
      expect(out.map((r) => r.id), ['r1', 'r3']);
    });
    test('Respects limit', () {
      final all = List.generate(10, (i) => Recipe('r$i', 'a1'));
      final out = followingFeed(all: all, authorIds: ['a1'], limit: 3);
      expect(out.length, 3);
      expect(out.map((r) => r.id), ['r0', 'r1', 'r2']);
    });
  });
}

