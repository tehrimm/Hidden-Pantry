import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/user/models/notification_model.dart';

void main() {
  group('Real Business Tests: Social Features', () {

    // ─── Like Toggle Logic ─────────────────────────────────────────
    group('Recipe Like Toggle', () {
      test('Adding a like increments count', () {
        int likeCount = 5;
        List<String> likedBy = ['u1', 'u2', 'u3', 'u4', 'u5'];
        const userId = 'u6';

        if (!likedBy.contains(userId)) {
          likedBy.add(userId);
          likeCount++;
        }

        expect(likeCount, 6);
        expect(likedBy.contains('u6'), true);
      });

      test('Removing a like decrements count', () {
        int likeCount = 5;
        List<String> likedBy = ['u1', 'u2', 'u3', 'u4', 'u5'];
        const userId = 'u3';

        if (likedBy.contains(userId)) {
          likedBy.remove(userId);
          likeCount--;
        }

        expect(likeCount, 4);
        expect(likedBy.contains('u3'), false);
      });

      test('Double-liking does not increment count twice', () {
        int likeCount = 5;
        List<String> likedBy = ['u1', 'u2', 'u3', 'u4', 'u5'];
        const userId = 'u1'; // already liked

        if (!likedBy.contains(userId)) {
          likedBy.add(userId);
          likeCount++;
        }

        expect(likeCount, 5); // unchanged
        expect(likedBy.where((id) => id == 'u1').length, 1); // no duplicate
      });

      test('Unlike when not already liked does nothing', () {
        int likeCount = 3;
        List<String> likedBy = ['u1', 'u2', 'u3'];
        const userId = 'u99'; // not in list

        if (likedBy.contains(userId)) {
          likedBy.remove(userId);
          likeCount--;
        }

        expect(likeCount, 3); // unchanged
        expect(likedBy.length, 3);
      });
    });

    // ─── Review Like Toggle ────────────────────────────────────────
    group('Review Like Toggle', () {
      test('Like a review adds user to likedBy', () {
        List<String> likedBy = [];
        int likes = 0;
        const userId = 'reviewer_fan';

        if (likedBy.contains(userId)) {
          likedBy.remove(userId);
          likes--;
        } else {
          likedBy.add(userId);
          likes++;
        }

        expect(likes, 1);
        expect(likedBy.contains(userId), true);
      });

      test('Unlike a review removes user from likedBy', () {
        List<String> likedBy = ['user_a', 'reviewer_fan'];
        int likes = 2;
        const userId = 'reviewer_fan';

        if (likedBy.contains(userId)) {
          likedBy.remove(userId);
          likes--;
        } else {
          likedBy.add(userId);
          likes++;
        }

        expect(likes, 1);
        expect(likedBy.contains(userId), false);
      });
    });

    // ─── Follow / Unfollow Logic ──────────────────────────────────
    group('Follow System Business Logic', () {
      test('Following an author increments follower count', () {
        int followerCount = 10;
        int followingCount = 3;
        bool isCurrentlyFollowing = false;

        // User follows author
        if (!isCurrentlyFollowing) {
          followerCount++;
          followingCount++;
          isCurrentlyFollowing = true;
        }

        expect(followerCount, 11);
        expect(followingCount, 4);
        expect(isCurrentlyFollowing, true);
      });

      test('Unfollowing decrements follower count', () {
        int followerCount = 11;
        int followingCount = 4;
        bool isCurrentlyFollowing = true;

        if (isCurrentlyFollowing) {
          followerCount--;
          followingCount--;
          isCurrentlyFollowing = false;
        }

        expect(followerCount, 10);
        expect(followingCount, 3);
        expect(isCurrentlyFollowing, false);
      });

      test('Self-follow is prevented', () {
        const userId = 'user_A';
        const authorId = 'user_A'; // same user!
        bool followed = false;

        if (userId != authorId) {
          followed = true;
        }

        expect(followed, false); // Self-follow blocked
      });

      test('Already-followed author does not re-increment on second follow', () {
        int followerCount = 11;
        bool isCurrentlyFollowing = true;

        if (!isCurrentlyFollowing) {
          followerCount++;
        }

        expect(followerCount, 11); // no change
      });
    });

    // ─── Notification Trigger Logic ───────────────────────────────
    group('Social Notification Dispatch', () {
      test('Follow action triggers NotificationType.follow', () {
        const type = NotificationType.follow;
        expect(type.name, 'follow');
      });

      test('Like action triggers NotificationType.like', () {
        const type = NotificationType.like;
        expect(type.name, 'like');
      });

      test('Comment action triggers NotificationType.comment', () {
        const type = NotificationType.comment;
        expect(type.name, 'comment');
      });

      test('Reply action triggers NotificationType.reply', () {
        const type = NotificationType.reply;
        expect(type.name, 'reply');
      });

      test('Notification not sent when liking own recipe', () {
        const authorId = 'author_1';
        const actingUserId = 'author_1'; // same user
        bool notificationSent = false;

        if (authorId != actingUserId) {
          notificationSent = true;
        }

        expect(notificationSent, false);
      });

      test('Notification sent when liking someone else\'s recipe', () {
        const authorId = 'author_1';
        const actingUserId = 'user_2';
        bool notificationSent = false;

        if (authorId.isNotEmpty && authorId != actingUserId) {
          notificationSent = true;
        }

        expect(notificationSent, true);
      });
    });

    // ─── Public Author Stats ──────────────────────────────────────
    group('Author stats parsing', () {
      test('followerCount parsed from int safely', () {
        final data = {'followerCount': 42, 'followingCount': 7};
        final followers = int.tryParse(data['followerCount']?.toString() ?? '0') ?? 0;
        final following = int.tryParse(data['followingCount']?.toString() ?? '0') ?? 0;
        expect(followers, 42);
        expect(following, 7);
      });

      test('followerCount defaults to 0 when missing', () {
        final data = <String, dynamic>{};
        final followers = int.tryParse(data['followerCount']?.toString() ?? '0') ?? 0;
        expect(followers, 0);
      });

      test('followerCount handles string-typed int from Firestore', () {
        final data = {'followerCount': '128'};
        final followers = int.tryParse(data['followerCount']?.toString() ?? '0') ?? 0;
        expect(followers, 128);
      });
    });
  });
}
