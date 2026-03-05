import 'package:flutter_test/flutter_test.dart';

class FollowState {
  final Set<String> following;
  final int followerCount; // how many follow the viewed profile
  const FollowState(this.following, this.followerCount);
}

FollowState follow(FollowState s, String authorId) {
  final next = Set<String>.from(s.following);
  final added = next.add(authorId);
  return FollowState(next, added ? s.followerCount + 1 : s.followerCount);
}

FollowState unfollow(FollowState s, String authorId) {
  final next = Set<String>.from(s.following);
  final removed = next.remove(authorId);
  final nextCount = removed ? (s.followerCount - 1) : s.followerCount;
  return FollowState(next, nextCount < 0 ? 0 : nextCount);
}

List<String> feedAfterFollow(Set<String> following, List<Map<String, String>> posts) {
  return posts.where((p) => following.contains(p['author'])).map((p) => p['id']!).toList();
}

void main() {
  group('Integration: Follow/Unfollow transitions', () {
    test('Following adds author to feed and increments follower count', () {
      final posts = [
        {'id': 'p1', 'author': 'a1'},
        {'id': 'p2', 'author': 'a2'},
      ];
      var s = FollowState({'a2'}.toSet(), 10);
      final before = feedAfterFollow(s.following, posts);
      expect(before, ['p2']);
      s = follow(s, 'a1');
      final after = feedAfterFollow(s.following, posts);
      expect(after.toSet(), {'p1', 'p2'});
      expect(s.followerCount, 11);
    });

    test('Unfollowing removes from feed and never drops count below zero', () {
      final posts = [
        {'id': 'p1', 'author': 'a1'},
        {'id': 'p2', 'author': 'a2'},
      ];
      var s = FollowState({'a1', 'a2'}.toSet(), 1);
      final before = feedAfterFollow(s.following, posts);
      expect(before.toSet(), {'p1', 'p2'});
      s = unfollow(s, 'a1');
      final after = feedAfterFollow(s.following, posts);
      expect(after, ['p2']);
      expect(s.followerCount, 0);
      s = unfollow(s, 'a1');
      expect(s.followerCount, 0);
    });
  });
}

