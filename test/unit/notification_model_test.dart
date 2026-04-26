import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/user/models/notification_model.dart';

void main() {
  group('AppNotification Model Tests', () {
    test('Standard construction', () {
      final now = DateTime.now();
      final notif = AppNotification(
        id: '1',
        recipientId: 'r1',
        senderId: 's1',
        senderName: 'Sender',
        title: 'Title',
        body: 'Body',
        type: NotificationType.like,
        timestamp: now,
      );
      expect(notif.id, '1');
      expect(notif.type, NotificationType.like);
      expect(notif.isRead, isFalse);
    });

    test('Enum to string mapping', () {
      expect(NotificationType.like.name, 'like');
      expect(NotificationType.comment.name, 'comment');
      expect(NotificationType.nutritionist_post.name, 'nutritionist_post');
    });
    test('toMap stores expected shape', () {
      final notif = AppNotification(
        id: 'n2',
        recipientId: 'r2',
        senderId: 's2',
        senderName: 'Sam',
        title: 'Hello',
        body: 'Body',
        type: NotificationType.subscription_alert,
        timestamp: DateTime.now(),
        isRead: true,
      );

      final map = notif.toMap();
      expect(map['recipientId'], 'r2');
      expect(map['senderName'], 'Sam');
      expect(map['type'], 'subscription_alert');
      expect(map['read'], true);
    });
  });
}
