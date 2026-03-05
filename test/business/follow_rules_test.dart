import 'package:flutter_test/flutter_test.dart';

class FollowState {
  final Set<String> following; // set of userIds current user follows
  const FollowState(this.following);
}

bool canFollow({required String currentUserId, required String targetUserId}) {
  return currentUserId.toLowerCase() != targetUserId.toLowerCase();
}

FollowState toggleFollow({
  required FollowState state,
  required String currentUserId,
  required String targetUserId,
}) {
  if (!canFollow(currentUserId: currentUserId, targetUserId: targetUserId)) {
    return state;
  }
  final next = Set<String>.from(state.following);
  final key = targetUserId.toLowerCase();
  if (next.any((e) => e.toLowerCase() == key)) {
    next.removeWhere((e) => e.toLowerCase() == key);
  } else {
    next.add(targetUserId);
  }
  return FollowState(next);
}

int followerCount(Set<String> followers) => followers.length;

void main() {
  group('Business: Follow rules', () {
    test('User cannot follow self', () {
      final s0 = FollowState(<String>{});
      final s1 = toggleFollow(state: s0, currentUserId: 'u1', targetUserId: 'U1');
      expect(s1.following.isEmpty, true);
    });
    test('Follow is idempotent toggle', () {
      final s0 = FollowState(<String>{});
      final s1 = toggleFollow(state: s0, currentUserId: 'me', targetUserId: 'u2');
      final s2 = toggleFollow(state: s1, currentUserId: 'me', targetUserId: 'U2');
      expect(s1.following.isNotEmpty, true);
      expect(s2.following.isEmpty, true);
    });
    test('Follower count computes from set size', () {
      final followers = {'a', 'b', 'c'}.toSet();
      expect(followerCount(followers), 3);
    });
  });
}

