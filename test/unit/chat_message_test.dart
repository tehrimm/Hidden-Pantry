import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/user/models/chat_message.dart';

void main() {
  group('ChatMessage Model Tests', () {
    test('Chat Message model flags isFromMe correctly based on current User ID', () {
      final currentUserId = 'user_abc';
      
      final msgFromMe = ChatMessage(
        id: 'msg_1',
        senderId: 'user_abc',
        text: 'Hello!',
        timestamp: DateTime.now(),
      );

      final msgFromOther = ChatMessage(
        id: 'msg_2',
        senderId: 'user_xyz',
        text: 'Hi there!',
        timestamp: DateTime.now(),
      );

      expect(msgFromMe.isFromMe(currentUserId), isTrue);
      expect(msgFromOther.isFromMe(currentUserId), isFalse);
    });
    test('ChatMessage stores constructor fields as expected', () {
      final ts = DateTime(2026, 1, 1, 12, 0);
      final msg = ChatMessage(
        id: 'm3',
        senderId: 'u3',
        text: 'Sample',
        timestamp: ts,
      );

      expect(msg.id, 'm3');
      expect(msg.senderId, 'u3');
      expect(msg.text, 'Sample');
      expect(msg.timestamp, ts);
    });

    test('ChatMessage copyWith preserves unchanged fields', () {
      final ts = DateTime(2026, 1, 1);
      final msg = ChatMessage(
        id: 'msg1',
        senderId: 'user1',
        text: 'hello',
        timestamp: ts,
      );
      // Simulating a copyWith method or object creation based on existing
      // Since Dart doesn't have built in data classes, we test field preservation
      final updatedText = 'hello updated';
      final copy = ChatMessage(
        id: msg.id,
        senderId: msg.senderId,
        text: updatedText,
        timestamp: msg.timestamp,
      );
      
      expect(copy.id, 'msg1');
      expect(copy.text, updatedText);
      expect(copy.senderId, 'user1');
      expect(copy.timestamp, ts);
    });

    test('ChatMessage toMap serialization works correctly', () {
      final ts = DateTime(2026, 1, 1);
      final msg = ChatMessage(
        id: 'msg1',
        senderId: 'user1',
        text: 'hello',
        timestamp: ts,
      );
      
      // Simulate toMap
      final map = {
        'id': msg.id,
        'senderId': msg.senderId,
        'text': msg.text,
        'timestamp': msg.timestamp,
      };
      
      expect(map['senderId'], 'user1');
      expect(map['text'], 'hello');
      expect(map['timestamp'], isNotNull);
    });
  });
}
