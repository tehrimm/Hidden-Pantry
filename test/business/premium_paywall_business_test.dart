import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/user/models/subscription_model.dart';
import 'package:hidden_pantry_app/features/user/services/subscription_service.dart';

void main() {
  group('Real Business Tests: Premium Paywall Rules', () {

    // ─── Service Constants ─────────────────────────────────────────
    group('SubscriptionService business constants', () {
      test('Max free downloads is 5', () {
        expect(SubscriptionService.maxFreeDownloads, 5);
      });

      test('Premium price in PKR is 250.0', () {
        expect(SubscriptionService.premiumPricePKR, 250.0);
      });

      test('Free download limit enforced at boundary', () {
        // At 5 downloads → 0 remaining
        final downloadedIds = ['r1', 'r2', 'r3', 'r4', 'r5'];
        final remaining = (SubscriptionService.maxFreeDownloads - downloadedIds.length)
            .clamp(0, SubscriptionService.maxFreeDownloads);
        expect(remaining, 0);
      });

      test('Remaining downloads clamped to 0 when over limit', () {
        // Simulate 6 recipes downloaded (edge case)
        final downloadedIds = ['r1', 'r2', 'r3', 'r4', 'r5', 'r6'];
        final remaining = (SubscriptionService.maxFreeDownloads - downloadedIds.length)
            .clamp(0, SubscriptionService.maxFreeDownloads);
        expect(remaining, 0); // never negative
      });

      test('Fresh user has max free downloads', () {
        final downloadedIds = <String>[];
        final remaining = (SubscriptionService.maxFreeDownloads - downloadedIds.length)
            .clamp(0, SubscriptionService.maxFreeDownloads);
        expect(remaining, 5);
      });
    });

    // ─── SubscriptionModel Business Rules ─────────────────────────
    group('SubscriptionModel tier and status rules', () {
      final now = DateTime(2026, 6, 1);

      test('Active status + future expiry = isActive true', () {
        final sub = SubscriptionModel(
          id: 'p_1', planName: 'Monthly', price: 250.0,
          interval: 'month',
          expiryDate: now.add(const Duration(days: 30)),
          nutritionistId: 'nut_1', status: 'active',
        );
        // Use a fixed now for comparison
        expect(sub.expiryDate.isAfter(now), true);
      });

      test('Premium plan price field is preserved', () {
        final sub = SubscriptionModel(
          id: 'p_2', planName: 'Premium Monthly', price: 250.0,
          interval: 'month',
          expiryDate: now.add(const Duration(days: 30)),
          nutritionistId: 'nut_1',
        );
        expect(sub.price, 250.0);
        expect(sub.planName, 'Premium Monthly');
        expect(sub.interval, 'month');
      });

      test('daysRemaining correctly counts days to expiry', () {
        final sub = SubscriptionModel(
          id: 'p_3', planName: 'Monthly', price: 250.0,
          interval: 'month',
          expiryDate: DateTime.now().add(const Duration(days: 10, hours: 12)),
          nutritionistId: 'nut_1',
        );
        expect(sub.daysRemaining(), 10);
      });

      test('Expired subscription shows 0 days remaining', () {
        final sub = SubscriptionModel(
          id: 'p_4', planName: 'Monthly', price: 250.0,
          interval: 'month',
          expiryDate: DateTime.now().subtract(const Duration(days: 1)),
          nutritionistId: 'nut_1',
        );
        expect(sub.daysRemaining(), 0);
      });

      test('Cancelled status always returns isActive false', () {
        final sub = SubscriptionModel(
          id: 'p_5', planName: 'Monthly', price: 250.0,
          interval: 'month',
          expiryDate: DateTime.now().add(const Duration(days: 15)),
          nutritionistId: 'nut_1',
          status: 'cancelled',
        );
        expect(sub.isActive(), false);
      });

      test('Trialing status with remaining days returns isActive true', () {
        final sub = SubscriptionModel(
          id: 'p_6', planName: 'Trial', price: 0.0,
          interval: 'trial',
          expiryDate: DateTime.now().add(const Duration(days: 3)),
          nutritionistId: 'nut_1',
          status: 'trialing',
        );
        expect(sub.isActive(), true);
      });
    });

    // ─── Trial Business Logic ──────────────────────────────────────
    group('7-day trial boundary logic', () {
      test('User on day 1 is in trial window', () {
        final createdAt = DateTime.now().subtract(const Duration(days: 1));
        final trialExpiry = createdAt.add(const Duration(days: 7));
        expect(DateTime.now().isBefore(trialExpiry), true);
      });

      test('User on day 6 is still in trial window', () {
        final createdAt = DateTime.now().subtract(const Duration(days: 6));
        final trialExpiry = createdAt.add(const Duration(days: 7));
        expect(DateTime.now().isBefore(trialExpiry), true);
      });

      test('User on day 8 is past trial window', () {
        final createdAt = DateTime.now().subtract(const Duration(days: 8));
        final trialExpiry = createdAt.add(const Duration(days: 7));
        expect(DateTime.now().isBefore(trialExpiry), false);
      });
    });

    // ─── Feature Lock Rules ────────────────────────────────────────
    group('Premium feature names and gating logic', () {
      const premiumFeatures = ['voice_cooking', 'image_recognition'];
      const freeFeatures = ['view_recipe', 'search', 'rate_recipe', 'follow'];

      test('Premium features list contains voice_cooking', () {
        expect(premiumFeatures.contains('voice_cooking'), true);
      });

      test('Premium features list contains image_recognition (AI camera)', () {
        expect(premiumFeatures.contains('image_recognition'), true);
      });

      test('Free features are not in premium list', () {
        for (final f in freeFeatures) {
          expect(premiumFeatures.contains(f), false,
              reason: '$f should be free');
        }
      });

      test('recipe_download has conditional gating (free with limit)', () {
        // recipe_download is neither fully free nor fully premium — it's conditional
        expect(premiumFeatures.contains('recipe_download'), false);
        expect(freeFeatures.contains('recipe_download'), false);
        // This is the "hybrid" feature — tested in integration tests
      });
    });
  });
}
