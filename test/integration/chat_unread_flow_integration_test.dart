import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/state/state_management.dart';

void main() {
  group('Integration: Chat unread flow', () {
    test('Increment and reset', () {
      final c = ChatController();
      expect(c.unreadCount, 0);
      c.handleIncomingMessage();
      c.handleIncomingMessage();
      expect(c.unreadCount, 2);
      c.markAsRead();
      expect(c.unreadCount, 0);
    });
  });
}

