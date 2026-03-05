import 'package:flutter_test/flutter_test.dart';

class Post {
  final String id;
  final String authorId;
  Post(this.id, this.authorId);
}

List<Post> filterBlockedAuthors(List<Post> posts, List<String> blockedIds) {
  if (blockedIds.isEmpty) return posts;
  final blocked = blockedIds.map((e) => e.toLowerCase()).toSet();
  return posts.where((p) => !blocked.contains(p.authorId.toLowerCase())).toList();
}

void main() {
  group('Business: Blocked authors filtering', () {
    test('Empty blocked list retains all posts', () {
      final posts = [Post('p1', 'u1'), Post('p2', 'u2')];
      final out = filterBlockedAuthors(posts, const []);
      expect(out.length, 2);
    });
    test('Blocks matching authors case-insensitively', () {
      final posts = [Post('p1', 'u1'), Post('p2', 'U2')];
      final out = filterBlockedAuthors(posts, const ['u2']);
      expect(out.map((p) => p.id), ['p1']);
    });
    test('Blocks multiple authors', () {
      final posts = [Post('p1', 'a'), Post('p2', 'b'), Post('p3', 'c')];
      final out = filterBlockedAuthors(posts, const ['a', 'c']);
      expect(out.map((p) => p.id), ['p2']);
    });
  });
}

