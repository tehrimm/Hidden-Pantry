import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/user/services/subscription_service.dart';

void main() {
  group('Real Integration Tests: canUsePremiumFeature Combined Gateway', () {
    late SubscriptionService service;
    Map<String, dynamic>? mockUserData;
    List<Map<String, dynamic>> mockPlatformSubs = [];
    DateTime mockNow = DateTime(2026, 3, 15);

    final mockAuth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'test_uid_gateway'));

    setUp(() {
      mockPlatformSubs = [];
      mockUserData = {
        'isPremium': false,
        'createdAt': mockNow.subtract(const Duration(days: 30)), // Past trial
        'downloadedRecipeIds': [],
      };

      service = SubscriptionService.injectable(
        auth: mockAuth,
        now: () => mockNow,
        loadUserData: (uid) async => mockUserData,
        loadPlatformSubscriptions: (uid) async => mockPlatformSubs,
        loadNutritionistSubscriptions: (uid, nutId) async => [],
        appendDownloadedRecipeId: (uid, recipeId) async {},
      );
    });

    test('Free user past trial cannot use premium features', () async {
      expect(await service.canUsePremiumFeature(), false);
    });

    test('User in trial window can use premium features', () async {
      mockUserData!['createdAt'] = mockNow.subtract(const Duration(days: 5));
      expect(await service.canUsePremiumFeature(), true);
    });

    test('User on last day of trial can use premium features', () async {
      mockUserData!['createdAt'] = mockNow.subtract(const Duration(days: 6));
      expect(await service.canUsePremiumFeature(), true);
    });

    test('User exactly at trial expiry (7 days) is blocked', () async {
      mockUserData!['createdAt'] = mockNow.subtract(const Duration(days: 7));
      expect(await service.canUsePremiumFeature(), false);
    });

    test('Premium subscription expiry 1 minute ago — no access', () async {
      mockPlatformSubs = [
        {'expiryDate': mockNow.subtract(const Duration(minutes: 1))}
      ];
      expect(await service.canUsePremiumFeature(), false);
    });

    test('Premium subscription expiry tomorrow — access granted', () async {
      mockPlatformSubs = [
        {'expiryDate': mockNow.add(const Duration(days: 1))}
      ];
      expect(await service.canUsePremiumFeature(), true);
    });

    test('isPremium flag in user doc grants access', () async {
      mockUserData!['isPremium'] = true;
      expect(await service.canUsePremiumFeature(), true);
    });

    test('getRemainingDownloads returns 5 for fresh user', () async {
      expect(await service.getRemainingDownloads(), 5);
    });

    test('getRemainingDownloads counts remaining slots correctly', () async {
      mockUserData!['downloadedRecipeIds'] = ['r1', 'r2', 'r3'];
      expect(await service.getRemainingDownloads(), 2);
    });

    test('getRemainingDownloads clamps to 0 when over limit', () async {
      mockUserData!['downloadedRecipeIds'] = ['r1', 'r2', 'r3', 'r4', 'r5', 'r6'];
      expect(await service.getRemainingDownloads(), 0);
    });
  });
}
