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
  });
}
