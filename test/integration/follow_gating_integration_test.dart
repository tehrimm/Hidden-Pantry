import 'package:flutter_test/flutter_test.dart';

class Post {
  final String id;
  final String authorId;
  final int minTier;
  Post(this.id, this.authorId, this.minTier);
}

List<Post> feed({
  required List<Post> posts,
  required Set<String> following,
  required Set<String> blocked,
  required int userTier,
}) {
  return posts
      .where((p) => following.contains(p.authorId))
      .where((p) => !blocked.contains(p.authorId.toLowerCase()))
      .where((p) => userTier >= p.minTier)
      .toList();
}

void main() {
  group('Integration: Follow + content gating', () {
    test('Filters by follow, blocked, and tier', () {
      final posts = [
        Post('p1', 'a1', 0),
        Post('p2', 'a2', 2),
        Post('p3', 'A3', 1),
      ];
      final out = feed(
        posts: posts,
        following: {'a1', 'a2', 'a3'}.toSet(),
        blocked: {'a3'}.toSet(),
        userTier: 1,
      );
      // p2 requires tier 2 → gated; p3 blocked; p1 allowed
      expect(out.map((p) => p.id), ['p1']);
    });
  });
}

