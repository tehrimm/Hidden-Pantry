import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/user/models/notification_model.dart';

void main() {
  group('Real Business Tests: AppNotification Serialization', () {
    final now = DateTime(2026, 4, 26, 10, 0);

    AppNotification makeNotif(NotificationType type, {String? targetId}) {
      return AppNotification(
        id: 'n_${type.name}',
        recipientId: 'user_A',
        senderId: 'user_B',
        senderName: 'Bob',
        title: 'Test title',
        body: 'Test body',
        type: type,
        targetId: targetId,
        timestamp: now,
        isRead: false,
      );
    }

    group('toMap serializes each field correctly', () {
      test('like notification serializes correctly', () {
        final map = makeNotif(NotificationType.like, targetId: 'recipe_1').toMap();
        expect(map['type'], 'like');
        expect(map['recipientId'], 'user_A');
        expect(map['senderId'], 'user_B');
        expect(map['senderName'], 'Bob');
        expect(map['title'], 'Test title');
        expect(map['body'], 'Test body');
        expect(map['targetId'], 'recipe_1');
        expect(map['read'], false);
      });

      test('comment notification type serialized as string', () {
        final map = makeNotif(NotificationType.comment).toMap();
        expect(map['type'], 'comment');
      });

      test('reply notification type serialized as string', () {
        final map = makeNotif(NotificationType.reply).toMap();
        expect(map['type'], 'reply');
      });

      test('follow notification type serialized as string', () {
        final map = makeNotif(NotificationType.follow, targetId: 'user_B').toMap();
        expect(map['type'], 'follow');
        expect(map['targetId'], 'user_B');
      });

      test('chat_message notification type serialized as string', () {
        final map = makeNotif(NotificationType.chat_message, targetId: 'chat_123').toMap();
        expect(map['type'], 'chat_message');
        expect(map['targetId'], 'chat_123');
      });

      test('nutritionist_post notification type serialized as string', () {
        final map = makeNotif(NotificationType.nutritionist_post).toMap();
        expect(map['type'], 'nutritionist_post');
      });

      test('subscription_alert notification type serialized as string', () {
        final map = makeNotif(NotificationType.subscription_alert).toMap();
        expect(map['type'], 'subscription_alert');
      });
    });

    group('parseType maps all strings to correct enums', () {
      test('Parses all 7 known types correctly', () {
        final testCases = {
          'like': NotificationType.like,
          'comment': NotificationType.comment,
          'reply': NotificationType.reply,
          'follow': NotificationType.follow,
          'chat_message': NotificationType.chat_message,
          'nutritionist_post': NotificationType.nutritionist_post,
          'subscription_alert': NotificationType.subscription_alert,
        };

        for (final entry in testCases.entries) {
          final parsed = AppNotification.parseTypePublic(entry.key);
          expect(parsed, entry.value,
              reason: "'${entry.key}' should map to ${entry.value}");
        }
      });

      test('Unknown type defaults to like', () {
        expect(AppNotification.parseTypePublic('unknown'), NotificationType.like);
        expect(AppNotification.parseTypePublic(''), NotificationType.like);
        expect(AppNotification.parseTypePublic(null), NotificationType.like);
      });
    });

    group('AppNotification field defaults', () {
      test('isRead defaults to false when not specified', () {
        final notif = AppNotification(
          id: 'n1',
          recipientId: 'r1',
          senderId: 's1',
          senderName: 'Alice',
          title: 'T',
          body: 'B',
          type: NotificationType.like,
          timestamp: now,
        );
        expect(notif.isRead, false);
        expect(notif.senderPhotoUrl, null);
        expect(notif.targetId, null);
      });
    });
  });
}
