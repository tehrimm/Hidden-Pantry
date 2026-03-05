import 'package:flutter_test/flutter_test.dart';

class Post {
  final String id;
  final String authorId;
  final int minTier;
  Post(this.id, this.authorId, this.minTier);
}

List<Post> visibleFeed({
  required List<Post> posts,
  required Set<String> following,
  required int userTier,
}) {
  return posts
      .where((p) => following.contains(p.authorId))
      .where((p) => userTier >= p.minTier)
      .toList();
}

void main() {
  group('Integration: Feed visibility on tier change', () {
    test('Upgrading tier reveals additional posts from followed authors', () {
      final posts = [
        Post('p1', 'a1', 0),
        Post('p2', 'a2', 2),
        Post('p3', 'a3', 1),
      ];
      final following = {'a1', 'a2', 'a3'};
      final at0 = visibleFeed(posts: posts, following: following, userTier: 0).map((p) => p.id).toList();
      expect(at0, ['p1']);
      final at1 = visibleFeed(posts: posts, following: following, userTier: 1).map((p) => p.id).toList();
      expect(at1, ['p1', 'p3']);
      final at2 = visibleFeed(posts: posts, following: following, userTier: 2).map((p) => p.id).toList();
      expect(at2, ['p1', 'p2', 'p3']);
    });
  });
}

