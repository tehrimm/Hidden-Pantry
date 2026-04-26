import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/user/models/chat_message.dart';
import 'package:hidden_pantry_app/features/user/models/notification_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('Real Business Tests: Major Features (Chat & Notifications)', () {
    test('NotificationModel converts string type to enum correctly', () {
      final chatNotif = NotificationModel(
        id: '1',
        userId: 'u1',
        title: 'New Message',
        body: 'Hello',
        createdAt: DateTime.now(),
        type: NotificationModel.parseType('chat_message'),
        targetId: 'chat_123',
      );
      
      expect(chatNotif.type, NotificationType.chat_message);
      expect(chatNotif.targetId, 'chat_123');
      
      final postNotif = NotificationModel(
        id: '2',
        userId: 'u1',
        title: 'New Post',
        body: 'Look at this',
        createdAt: DateTime.now(),
        type: NotificationModel.parseType('new_post'),
        targetId: 'post_123',
      );
      
      expect(postNotif.type, NotificationType.new_post);
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
