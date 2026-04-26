import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/user/models/subscription_model.dart';

void main() {
  group('SubscriptionModel Tests', () {
    test('Subscription model calculates daysRemaining accurately based on expiry date', () {
      final now = DateTime.now();
      final expiry = now.add(const Duration(days: 10, hours: 2));
      
      final sub = SubscriptionModel(
        id: 'sub_123',
        planName: 'Pro Plan',
        price: 99.9,
        interval: 'month',
        expiryDate: expiry,
        nutritionistId: 'nut_1',
      );

      expect(sub.daysRemaining, 10);
    });

    test('daysRemaining should return 0 if subscription has expired', () {
      final past = DateTime.now().subtract(const Duration(days: 1));
      
      final sub = SubscriptionModel(
        id: 'sub_expired',
        planName: 'Pro Plan',
        price: 99.9,
        interval: 'month',
        expiryDate: past,
        nutritionistId: 'nut_1',
      );

      expect(sub.daysRemaining, 0);
    });

    test('isActive true for active status with future expiry', () {
      final sub = SubscriptionModel(
        id: 'sub_active',
        planName: 'Premium',
        price: 250.0,
        interval: 'month',
        expiryDate: DateTime.now().add(const Duration(days: 5)),
        nutritionistId: 'nut_1',
        status: 'active',
      );

      expect(sub.isActive, isTrue);
    });

    test('isActive true for trialing status with future expiry', () {
      final sub = SubscriptionModel(
        id: 'sub_trial',
        planName: 'Trial',
        price: 0,
        interval: 'month',
        expiryDate: DateTime.now().add(const Duration(days: 2)),
        nutritionistId: 'nut_1',
        status: 'trialing',
      );

      expect(sub.isActive, isTrue);
    });

    test('isActive false for canceled status even when not expired', () {
      final sub = SubscriptionModel(
        id: 'sub_canceled',
        planName: 'Premium',
        price: 250.0,
        interval: 'month',
        expiryDate: DateTime.now().add(const Duration(days: 10)),
        nutritionistId: 'nut_1',
        status: 'canceled',
      );

      expect(sub.isActive, isFalse);
    });
  });
}
