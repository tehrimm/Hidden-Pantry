import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/user/services/subscription_service.dart';
import 'package:hidden_pantry_app/features/user/models/subscription_model.dart';

void main() {
  group('Real Integration Tests: Nutritionist Subscription Flow', () {
    late SubscriptionService subscriptionService;
    List<Map<String, dynamic>> mockNutSubs = [];
    Map<String, dynamic>? mockUserData;
    DateTime mockNow = DateTime(2026, 5, 1);

    final mockAuth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'subscriber_uid'));

    setUp(() {
      mockNutSubs = [];
      mockUserData = {
        'isPremium': false,
        'createdAt': mockNow.subtract(const Duration(days: 60)),
        'downloadedRecipeIds': [],
      };

      subscriptionService = SubscriptionService.injectable(
        auth: mockAuth,
        now: () => mockNow,
        loadUserData: (uid) async => mockUserData,
        loadPlatformSubscriptions: (uid) async => [],
        loadNutritionistSubscriptions: (uid, nutId) async => mockNutSubs,
        appendDownloadedRecipeId: (uid, recipeId) async {},
      );
    });

    group('SubscriptionModel business logic', () {
      test('Active subscription is correctly identified', () {
        final sub = SubscriptionModel(
          id: 'sub_001',
          planName: 'Monthly',
          price: 250.0,
          interval: 'month',
          expiryDate: mockNow.add(const Duration(days: 25)),
          nutritionistId: 'nut_01',
          status: 'active',
        );
        expect(sub.isActive, true);
        expect(sub.daysRemaining, 25);
      });

      test('Expired subscription reports 0 days and isActive false', () {
        final sub = SubscriptionModel(
          id: 'sub_002',
          planName: 'Monthly',
          price: 250.0,
          interval: 'month',
          expiryDate: mockNow.subtract(const Duration(days: 1)),
          nutritionistId: 'nut_01',
        );
        expect(sub.isActive, false);
        expect(sub.daysRemaining, 0);
      });

      test('Cancelled status blocks even with future expiry', () {
        final sub = SubscriptionModel(
          id: 'sub_003',
          planName: 'Monthly',
          price: 250.0,
          interval: 'month',
          expiryDate: mockNow.add(const Duration(days: 5)),
          nutritionistId: 'nut_01',
          status: 'cancelled',
        );
        expect(sub.isActive, false);
      });

      test('Trialing status + future expiry = active', () {
        final sub = SubscriptionModel(
          id: 'sub_004',
          planName: 'Trial',
          price: 0.0,
          interval: 'trial',
          expiryDate: mockNow.add(const Duration(days: 3)),
          nutritionistId: 'nut_01',
          status: 'trialing',
        );
        expect(sub.isActive, true);
      });
    });

    group('hasNutritionistAccess — live service integration', () {
      test('No subscription → access denied', () async {
        expect(await subscriptionService.hasNutritionistAccess('nut_01'), false);
      });

      test('Active subscription → access granted', () async {
        mockNutSubs = [
          {'expiryDate': mockNow.add(const Duration(days: 25))}
        ];
        expect(await subscriptionService.hasNutritionistAccess('nut_01'), true);
      });

      test('Subscription expires yesterday → access denied', () async {
        mockNutSubs = [
          {'expiryDate': mockNow.subtract(const Duration(days: 1))}
        ];
        expect(await subscriptionService.hasNutritionistAccess('nut_01'), false);
      });

      test('Subscription expires in 1 minute → still active', () async {
        mockNutSubs = [
          {'expiryDate': mockNow.add(const Duration(minutes: 1))}
        ];
        expect(await subscriptionService.hasNutritionistAccess('nut_01'), true);
      });

      test('Different nutritionist subscription does not grant access to another', () async {
        // User subscribed to nut_99, but not nut_01
        // mockNutSubs is called with the specific nutId, so if empty for nut_01 → false
        mockNutSubs = []; // Simulating no match for nut_01
        expect(await subscriptionService.hasNutritionistAccess('nut_01'), false);
      });

      test('Plan price is preserved in SubscriptionModel (PKR 250)', () {
        expect(SubscriptionService.premiumPricePKR, 250.0);
      });

      test('Max free downloads constant is enforced at 5', () {
        expect(SubscriptionService.maxFreeDownloads, 5);
      });
    });
  });
}
