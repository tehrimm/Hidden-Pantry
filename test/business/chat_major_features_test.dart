import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/user/models/chat_message.dart';
import 'package:hidden_pantry_app/features/user/models/notification_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('Real Business Tests: Major Features (Chat & Notifications)', () {
    test('NotificationModel converts string type to enum correctly', () {
      final chatNotif = AppNotification(
        id: '1',
        recipientId: 'u1',
        senderId: 'u2',
        senderName: 'Sender',
        title: 'New Message',
        body: 'Hello',
        timestamp: DateTime.now(),
        type: AppNotification.parseTypePublic('chat_message'),
        targetId: 'chat_123',
      );
      
      expect(chatNotif.type, NotificationType.chat_message);
      expect(chatNotif.targetId, 'chat_123');
      
      final postNotif = AppNotification(
        id: '2',
        recipientId: 'u1',
        senderId: 'u3',
        senderName: 'Nutri',
        title: 'New Post',
        body: 'Look at this',
        timestamp: DateTime.now(),
        type: AppNotification.parseTypePublic('nutritionist_post'),
        targetId: 'post_123',
      );
      
      expect(postNotif.type, NotificationType.nutritionist_post);
    });

    test('ChatMessage initializes correctly from raw data', () {
      final now = DateTime.now();
      final msg = ChatMessage(
        id: 'msg1',
        senderId: 'user1',
        text: 'Hey Doc!',
        timestamp: now,
        isRead: false,
      );
      
      expect(msg.id, 'msg1');
      expect(msg.senderId, 'user1');
      expect(msg.text, 'Hey Doc!');
      expect(msg.isRead, false);
      
      // Simulate reading
      final readMsg = ChatMessage(
        id: msg.id,
        senderId: msg.senderId,
        text: msg.text,
        timestamp: msg.timestamp,
        isRead: true,
      );
      
      expect(readMsg.isRead, true);
    });
  });
}
