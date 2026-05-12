import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/user/services/subscription_service.dart';

void main() {
  group('Real Integration Tests: Subscription & Paywall Feature Gating', () {
    late SubscriptionService service;
    Map<String, dynamic>? mockUserData;
    List<Map<String, dynamic>> mockPlatformSubs = [];
    List<Map<String, dynamic>> mockNutSubs = [];
    DateTime mockNow = DateTime(2026, 1, 10);
    List<String> appendedRecipes = [];

    // Use a real MockFirebaseAuth so currentUser is non-null
    final mockAuth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'test_uid_001'));

    setUp(() {
      mockUserData = {
        'isPremium': false,
        'trialExpiresAt': mockNow.subtract(const Duration(days: 10)), // 10 days old - past trial
        'downloadedRecipeIds': [],
      };
      mockPlatformSubs = [];
      mockNutSubs = [];
      appendedRecipes = [];

      service = SubscriptionService.injectable(
        auth: mockAuth,
        now: () => mockNow,
        loadUserData: (uid) async => mockUserData,
        loadPlatformSubscriptions: (uid) async => mockPlatformSubs,
        loadNutritionistSubscriptions: (uid, nutId) async => mockNutSubs,
        appendDownloadedRecipeId: (uid, recipeId) async {
          appendedRecipes.add(recipeId);
        },
      );
    });

    group('Trial Period', () {
      test('isTrialActive returns false after 7 days have passed', () async {
        expect(await service.isTrialActive(), false);
      });

      test('isTrialActive returns true within 7-day window', () async {
        mockUserData!['trialExpiresAt'] = mockNow.add(const Duration(days: 4));
        expect(await service.isTrialActive(), true);
      });

      test('Trial expires exactly on day 7', () async {
        mockUserData!['trialExpiresAt'] = mockNow;
        expect(await service.isTrialActive(), false); // 7 days == expiry, not before
      });
    });

    group('Premium Status', () {
      test('isPremiumUser returns false for free user with no subscriptions', () async {
        expect(await service.isPremiumUser(), false);
      });

      test('isPremiumUser returns true when isPremium flag is set in user doc', () async {
        mockUserData!['isPremium'] = true;
        expect(await service.isPremiumUser(), true);
      });

      test('isPremiumUser returns true with active platform subscription', () async {
        mockPlatformSubs = [
          {'expiryDate': mockNow.add(const Duration(days: 30))}
        ];
        expect(await service.isPremiumUser(), true);
      });

      test('isPremiumUser returns false with expired platform subscription', () async {
        mockPlatformSubs = [
          {'expiryDate': mockNow.subtract(const Duration(days: 1))}
        ];
        expect(await service.isPremiumUser(), false);
      });
    });

    group('Feature Gating: voice_cooking & image_recognition', () {
      test('voice_cooking locked for free user past trial', () async {
        expect(await service.canUseFeature('voice_cooking'), false);
      });

      test('voice_cooking unlocked for trial user', () async {
        mockUserData!['trialExpiresAt'] = mockNow.add(const Duration(days: 4));
        expect(await service.canUseFeature('voice_cooking'), true);
      });

      test('image_recognition locked for free user past trial', () async {
        expect(await service.canUseFeature('image_recognition'), false);
      });

      test('image_recognition unlocked for premium user', () async {
        mockPlatformSubs = [{'expiryDate': mockNow.add(const Duration(days: 30))}];
        expect(await service.canUseFeature('image_recognition'), true);
      });
    });

    group('Feature Gating: recipe_download limits', () {
      test('recipe_download allowed when free slots remain', () async {
        mockUserData!['downloadedRecipeIds'] = ['r1', 'r2'];
        expect(await service.canUseFeature('recipe_download'), true);
      });

      test('recipe_download blocked when 5/5 slots used', () async {
        mockUserData!['downloadedRecipeIds'] = ['r1', 'r2', 'r3', 'r4', 'r5'];
        expect(await service.canUseFeature('recipe_download'), false);
      });

      test('recipe_download unlimited for premium users', () async {
        mockPlatformSubs = [{'expiryDate': mockNow.add(const Duration(days: 30))}];
        mockUserData!['downloadedRecipeIds'] = ['r1', 'r2', 'r3', 'r4', 'r5']; // All slots used
        expect(await service.canUseFeature('recipe_download'), true); // Premium bypasses
      });
    });

    group('trackDownload logic', () {
      test('trackDownload appends new recipe and returns true', () async {
        expect(await service.trackDownload('r_new'), true);
        expect(appendedRecipes.contains('r_new'), true);
      });

      test('trackDownload returns true for already-downloaded recipe (no double count)', () async {
        mockUserData!['downloadedRecipeIds'] = ['r1', 'r2', 'r3', 'r4', 'r5'];
        expect(await service.trackDownload('r1'), true); // Already counted
        expect(appendedRecipes.isEmpty, true); // No new append
      });

      test('trackDownload blocks 6th unique recipe', () async {
        mockUserData!['downloadedRecipeIds'] = ['r1', 'r2', 'r3', 'r4', 'r5'];
        expect(await service.trackDownload('r6'), false);
        expect(appendedRecipes.isEmpty, true);
      });
    });

    group('getRemainingDownloads', () {
      test('Returns 5 for fresh user with no downloads', () async {
        expect(await service.getRemainingDownloads(), 5);
      });

      test('Correctly counts remaining slots', () async {
        mockUserData!['downloadedRecipeIds'] = ['r1', 'r2', 'r3'];
        expect(await service.getRemainingDownloads(), 2);
      });

      test('Clamps to 0 when over limit (never negative)', () async {
        mockUserData!['downloadedRecipeIds'] = ['r1', 'r2', 'r3', 'r4', 'r5', 'r6'];
        expect(await service.getRemainingDownloads(), 0);
      });
    });

    group('hasNutritionistAccess', () {
      test('Blocks access with no subscription', () async {
        expect(await service.hasNutritionistAccess('nut1'), false);
      });

      test('Blocks access with expired subscription', () async {
        mockNutSubs = [{'expiryDate': mockNow.subtract(const Duration(days: 5))}];
        expect(await service.hasNutritionistAccess('nut1'), false);
      });

      test('Grants access with active subscription', () async {
        mockNutSubs = [{'expiryDate': mockNow.add(const Duration(days: 30))}];
        expect(await service.hasNutritionistAccess('nut1'), true);
      });
    });
  });
}
