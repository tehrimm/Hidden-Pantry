import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/user/services/subscription_service.dart';

void main() {
  group('Real Integration Tests: Feature Gating canUseFeature', () {
    late SubscriptionService service;
    Map<String, dynamic>? mockUserData;
    List<Map<String, dynamic>> mockPlatformSubs = [];
    DateTime mockNow = DateTime(2026, 1, 10);

    final mockAuth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'test_uid_gate'));

    setUp(() {
      mockPlatformSubs = [];
      mockUserData = {
        'isPremium': false,
        'createdAt': mockNow.subtract(const Duration(days: 10)),
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

    group('Image Recognition (Camera AI) gating', () {
      test('image_recognition locked for free user past trial', () async {
        expect(await service.canUseFeature('image_recognition'), false);
      });

      test('image_recognition unlocked for premium user', () async {
        mockPlatformSubs = [{'expiryDate': mockNow.add(const Duration(days: 30))}];
        expect(await service.canUseFeature('image_recognition'), true);
      });

      test('image_recognition unlocked for trial user', () async {
        mockUserData!['createdAt'] = mockNow.subtract(const Duration(days: 3));
        expect(await service.canUseFeature('image_recognition'), true);
      });
    });

    group('Recipe Download gating', () {
      test('recipe_download allowed when premium', () async {
        mockPlatformSubs = [{'expiryDate': mockNow.add(const Duration(days: 30))}];
        expect(await service.canUseFeature('recipe_download'), true);
      });

      test('recipe_download allowed when free slots remain', () async {
        mockUserData!['downloadedRecipeIds'] = ['r1', 'r2'];
        expect(await service.canUseFeature('recipe_download'), true);
      });

      test('recipe_download blocked when free limit reached (5/5)', () async {
        mockUserData!['downloadedRecipeIds'] = ['r1', 'r2', 'r3', 'r4', 'r5'];
        expect(await service.canUseFeature('recipe_download'), false);
      });
    });

    group('Default / unknown feature access', () {
      test('Unknown features default to allowed', () async {
        expect(await service.canUseFeature('view_recipe'), true);
        expect(await service.canUseFeature('rate_recipe'), true);
        expect(await service.canUseFeature('any_unknown'), true);
      });
    });

    group('Download idempotency', () {
      test('Already-downloaded recipe returns true (no double-counting)', () async {
        mockUserData!['downloadedRecipeIds'] = ['r1', 'r2', 'r3', 'r4', 'r5'];
        expect(await service.trackDownload('r1'), true); // r1 exists → true
      });

      test('New recipe blocked when limit is full', () async {
        mockUserData!['downloadedRecipeIds'] = ['r1', 'r2', 'r3', 'r4', 'r5'];
        expect(await service.trackDownload('r6'), false);
      });
    });
  });
}
