import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/user/models/subscription_model.dart';

void main() {
  group('Real Business Tests: SubscriptionModel', () {
    test('daysRemaining returns 0 if expiry date is in the past', () {
      final pastSub = SubscriptionModel(
        id: '1',
        planName: 'Basic',
        price: 9.99,
        interval: 'month',
        expiryDate: DateTime.now().subtract(const Duration(days: 5)),
        nutritionistId: 'nut1',
      );
      
      expect(pastSub.daysRemaining(), 0);
    });

    test('daysRemaining returns correct positive number for future expiry', () {
      final futureSub = SubscriptionModel(
        id: '2',
        planName: 'Basic',
        price: 9.99,
        interval: 'month',
        // Add 5 days and 12 hours to safely expect exactly 5 full days difference
        expiryDate: DateTime.now().add(const Duration(days: 5, hours: 12)),
        nutritionistId: 'nut1',
      );
      
      expect(futureSub.daysRemaining(), 5);
    });

    test('isActive returns false if status is cancelled', () {
      final cancelledSub = SubscriptionModel(
        id: '3',
        planName: 'Basic',
        price: 9.99,
        interval: 'month',
        expiryDate: DateTime.now().add(const Duration(days: 10)),
        nutritionistId: 'nut1',
        status: 'cancelled', // Explicitly cancelled
      );
      
      expect(cancelledSub.isActive(), false);
    });

    test('isActive returns false if daysRemaining is 0 despite active status', () {
      final expiredSub = SubscriptionModel(
        id: '4',
        planName: 'Basic',
        price: 9.99,
        interval: 'month',
        expiryDate: DateTime.now().subtract(const Duration(days: 1)),
        nutritionistId: 'nut1',
        status: 'active', // Status is active but date is expired
      );
      
      expect(expiredSub.isActive(), false);
    });

    test('isActive returns true for active status with remaining days', () {
      final goodSub = SubscriptionModel(
        id: '5',
        planName: 'Basic',
        price: 9.99,
        interval: 'month',
        expiryDate: DateTime.now().add(const Duration(days: 10)),
        nutritionistId: 'nut1',
        status: 'active',
      );
      
      expect(goodSub.isActive(), true);
    });

    test('isActive returns true for trialing status with remaining days', () {
      final trialSub = SubscriptionModel(
        id: '6',
        planName: 'Basic',
        price: 9.99,
        interval: 'month',
        expiryDate: DateTime.now().add(const Duration(days: 10)),
        nutritionistId: 'nut1',
        status: 'trialing',
      );
      
      expect(trialSub.isActive(), true);
    });
  });
}
