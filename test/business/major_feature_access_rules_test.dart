import 'package:flutter_test/flutter_test.dart';

bool isSubscriptionActive({
  required String status,
  required DateTime? expiryAt,
  required DateTime now,
}) {
  if (status.toLowerCase() == 'active') return true;
  if (expiryAt == null) return false;
  return expiryAt.isAfter(now);
}

bool canUseFeature({
  required String featureKey,
  required bool subscriptionActive,
  required bool trialActive,
}) {
  if (featureKey == 'basic_search') return true;
  if (featureKey == 'voice_cooking') return subscriptionActive || trialActive;
  if (featureKey == 'ingredient_scan') return subscriptionActive || trialActive;
  if (featureKey == 'nutritionist_chat') return subscriptionActive || trialActive;
  return false;
}

int remainingDownloads({
  required int monthlyLimit,
  required int used,
}) {
  final left = monthlyLimit - used;
  return left < 0 ? 0 : left;
}

void main() {
  group('Business: Major feature access rules', () {
    test('Explicit active status is active regardless of expiry field', () {
      final now = DateTime(2026, 4, 26);
      expect(
        isSubscriptionActive(
          status: 'active',
          expiryAt: now.subtract(const Duration(days: 1)),
          now: now,
        ),
        true,
      );
    });

    test('Future expiry keeps subscription active even without active status', () {
      final now = DateTime(2026, 4, 26);
      expect(
        isSubscriptionActive(
          status: 'inactive',
          expiryAt: now.add(const Duration(days: 3)),
          now: now,
        ),
        true,
      );
    });

    test('Premium-only features require active subscription or trial', () {
      expect(
        canUseFeature(
          featureKey: 'voice_cooking',
          subscriptionActive: false,
          trialActive: false,
        ),
        false,
      );
      expect(
        canUseFeature(
          featureKey: 'voice_cooking',
          subscriptionActive: false,
          trialActive: true,
        ),
        true,
      );
    });

    test('Ingredient scan and nutritionist chat follow same premium gate', () {
      expect(
        canUseFeature(
          featureKey: 'ingredient_scan',
          subscriptionActive: true,
          trialActive: false,
        ),
        true,
      );
      expect(
        canUseFeature(
          featureKey: 'nutritionist_chat',
          subscriptionActive: false,
          trialActive: false,
        ),
        false,
      );
    });

    test('Basic search remains available to non-premium users', () {
      expect(
        canUseFeature(
          featureKey: 'basic_search',
          subscriptionActive: false,
          trialActive: false,
        ),
        true,
      );
    });

    test('Remaining downloads never drops below zero', () {
      expect(remainingDownloads(monthlyLimit: 10, used: 4), 6);
      expect(remainingDownloads(monthlyLimit: 10, used: 12), 0);
    });
  });
}
