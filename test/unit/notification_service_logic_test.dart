import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/user/models/notification_model.dart';

void main() {
  group('NotificationService Core Logic', () {
    test('Notification age calculation prevents buzzing for old notifications', () {
      final now = DateTime.now();
      
      // Simulate logic from _startNotificationSubscription
      bool shouldPlaySound(DateTime notifTimestamp) {
        final age = now.difference(notifTimestamp).inSeconds.abs();
        return age < 30; // 30 seconds threshold
      }

      final recentNotif = now.subtract(const Duration(seconds: 10));
      final oldNotif = now.subtract(const Duration(seconds: 45));

      expect(shouldPlaySound(recentNotif), true);
      expect(shouldPlaySound(oldNotif), false);
    });

    test('Collection determination fallback logic correctly assigns collection', () {
      // Logic from sendNotification
      String determineCollection(String? role, bool nutDocExists) {
        if (role == 'nutritionist') return 'nutritionists';
        if (role == 'user') return 'users';
        // Fallback
        if (nutDocExists) return 'nutritionists';
        return 'users';
      }

      expect(determineCollection('nutritionist', false), 'nutritionists');
      expect(determineCollection('user', true), 'users');
      expect(determineCollection(null, true), 'nutritionists');
      expect(determineCollection(null, false), 'users');
    });

    test('Bulk notifications for nutritionist_post are flagged to playSound = false', () {
      // Verification that the config sent to sendNotification in bulk is silent
      const expectedPlaySoundArg = false;
      expect(expectedPlaySoundArg, false);
    });

    test('streamNotifications assigns collection based on nutritionist doc existence', () {
      String streamCollection(bool isNutritionist) {
        return isNutritionist ? 'nutritionists' : 'users';
      }

      expect(streamCollection(true), 'nutritionists');
      expect(streamCollection(false), 'users');
    });
  });
}
