import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/user/models/user_model.dart';
import 'package:hidden_pantry_app/features/user/models/notification_model.dart';
import 'package:hidden_pantry_app/features/user/models/chat_message.dart';

void main() {
  group('Real Business Tests: UserModel', () {
    late UserModel baseUser;

    setUp(() {
      baseUser = UserModel(
        uid: 'uid_001',
        email: 'alice@example.com',
        fullName: 'Alice Doe',
        role: 'homecook',
        allergies: ['peanut', 'dairy'],
        createdAt: DateTime(2025, 1, 1),
      );
    });

    test('UserModel initializes all fields correctly', () {
      expect(baseUser.uid, 'uid_001');
      expect(baseUser.email, 'alice@example.com');
      expect(baseUser.fullName, 'Alice Doe');
      expect(baseUser.role, 'homecook');
      expect(baseUser.allergies, ['peanut', 'dairy']);
    });

    test('copyWith updates only specified fields', () {
      final updated = baseUser.copyWith(role: 'nutritionist', fullName: 'Alice Smith');
      expect(updated.role, 'nutritionist');
      expect(updated.fullName, 'Alice Smith');
      // Original unchanged
      expect(updated.uid, 'uid_001');
      expect(updated.email, 'alice@example.com');
      expect(updated.allergies, ['peanut', 'dairy']);
    });

    test('copyWith with new allergies list replaces correctly', () {
      final updated = baseUser.copyWith(allergies: ['gluten']);
      expect(updated.allergies, ['gluten']);
      expect(updated.allergies.length, 1);
    });

    test('toMap serializes correctly', () {
      final map = baseUser.toMap();
      expect(map['email'], 'alice@example.com');
      expect(map['fullName'], 'Alice Doe');
      expect(map['role'], 'homecook');
      expect(map['allergies'], ['peanut', 'dairy']);
    });

    test('UserModel with no allergies defaults to empty list', () {
      final noAllergyUser = UserModel(
        uid: 'uid_002',
        email: 'bob@test.com',
        fullName: 'Bob',
        role: 'homecook',
      );
      expect(noAllergyUser.allergies, isEmpty);
    });
  });

  group('Real Business Tests: AppNotification model', () {
    late AppNotification baseNotif;

    setUp(() {
      baseNotif = AppNotification(
        id: 'notif_1',
        recipientId: 'user_A',
        senderId: 'user_B',
        senderName: 'Bob',
        title: 'New follower',
        body: 'Bob started following you',
        type: NotificationType.follow,
        timestamp: DateTime(2026, 1, 1),
      );
    });

    test('AppNotification initializes with defaults', () {
      expect(baseNotif.isRead, false);
      expect(baseNotif.senderPhotoUrl, null);
      expect(baseNotif.targetId, null);
    });

    test('toMap serializes type as string name', () {
      final map = baseNotif.toMap();
      expect(map['type'], 'follow');
      expect(map['read'], false);
      expect(map['recipientId'], 'user_A');
      expect(map['senderId'], 'user_B');
    });

    test('parseType maps all known notification strings to enums', () {
      expect(AppNotification.parseTypePublic('like'), NotificationType.like);
      expect(AppNotification.parseTypePublic('comment'), NotificationType.comment);
      expect(AppNotification.parseTypePublic('reply'), NotificationType.reply);
      expect(AppNotification.parseTypePublic('follow'), NotificationType.follow);
      expect(AppNotification.parseTypePublic('chat_message'), NotificationType.chat_message);
      expect(AppNotification.parseTypePublic('nutritionist_post'), NotificationType.nutritionist_post);
      expect(AppNotification.parseTypePublic('subscription_alert'), NotificationType.subscription_alert);
    });

    test('parseType falls back to like for unknown string', () {
      expect(AppNotification.parseTypePublic('unknown_type'), NotificationType.like);
      expect(AppNotification.parseTypePublic(null), NotificationType.like);
    });
  });

  group('Real Business Tests: ChatMessage model', () {
    test('isFromMe correctly identifies message ownership', () {
      final msg = ChatMessage(
        id: 'msg_1',
        senderId: 'user_A',
        text: 'Hello!',
        timestamp: DateTime.now(),
      );

      expect(msg.isFromMe('user_A'), true);
      expect(msg.isFromMe('user_B'), false);
    });

    test('ChatMessage stores all fields correctly', () {
      final now = DateTime(2026, 4, 1, 10, 30);
      final msg = ChatMessage(
        id: 'msg_2',
        senderId: 'nut_1',
        text: 'Your meal plan is ready!',
        timestamp: now,
      );

      expect(msg.id, 'msg_2');
      expect(msg.senderId, 'nut_1');
      expect(msg.text, 'Your meal plan is ready!');
      expect(msg.timestamp, now);
    });

    test('Multiple messages from different senders are correctly distinguished', () {
      final userMsg = ChatMessage(id: 'm1', senderId: 'u1', text: 'Hi', timestamp: DateTime.now());
      final nutMsg = ChatMessage(id: 'm2', senderId: 'n1', text: 'Hello', timestamp: DateTime.now());

      expect(userMsg.isFromMe('u1'), true);
      expect(userMsg.isFromMe('n1'), false);
      expect(nutMsg.isFromMe('n1'), true);
      expect(nutMsg.isFromMe('u1'), false);
    });
  });
}
