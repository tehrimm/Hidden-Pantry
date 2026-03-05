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
  });
}
