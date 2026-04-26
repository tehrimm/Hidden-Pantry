import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/user/services/subscription_service.dart';

void main() {
  group('SubscriptionService branch matrix', () {
    late MockFirebaseAuth auth;
    final now = DateTime(2026, 4, 25, 12, 0);

    setUp(() async {
      auth = MockFirebaseAuth();
      await auth.signInWithEmailAndPassword(email: 'u@test.com', password: 'pw');
    });

    test('isPremiumUser true when active platform subscription expiry in future', () async {
      final service = SubscriptionService.injectable(
        auth: auth,
        now: () => now,
        loadPlatformSubscriptions: (_) async => [
          {'expiryDate': Timestamp.fromDate(now.add(const Duration(days: 1)))}
        ],
        loadUserData: (_) async => {'isPremium': false},
      );

      expect(await service.isPremiumUser(), isTrue);
    });

    test('isPremiumUser falls back to user isPremium flag', () async {
      final service = SubscriptionService.injectable(
        auth: auth,
        now: () => now,
        loadPlatformSubscriptions: (_) async => [],
        loadUserData: (_) async => {'isPremium': true},
      );

      expect(await service.isPremiumUser(), isTrue);
    });

    test('isTrialActive true when createdAt inside 7 days', () async {
      final service = SubscriptionService.injectable(
        auth: auth,
        now: () => now,
        loadUserData: (_) async => {
          'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 3))),
        },
      );

      expect(await service.isTrialActive(), isTrue);
    });

    test('isTrialActive false when createdAt older than 7 days', () async {
      final service = SubscriptionService.injectable(
        auth: auth,
        now: () => now,
        loadUserData: (_) async => {
          'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 8))),
        },
      );

      expect(await service.isTrialActive(), isFalse);
    });

    test('getRemainingDownloads clamps to zero when over limit', () async {
      final service = SubscriptionService.injectable(
        auth: auth,
        loadUserData: (_) async => {
          'downloadedRecipeIds': List.generate(8, (i) => 'r$i'),
        },
      );

      expect(await service.getRemainingDownloads(), 0);
    });

    test('trackDownload allows already-counted recipe for free user', () async {
      final service = SubscriptionService.injectable(
        auth: auth,
        now: () => now,
        loadPlatformSubscriptions: (_) async => [],
        loadUserData: (_) async => {
          'isPremium': false,
          'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 30))),
          'downloadedRecipeIds': ['r1', 'r2'],
        },
      );

      expect(await service.trackDownload('r1'), isTrue);
    });

    test('trackDownload blocks new recipe when free limit reached', () async {
      final service = SubscriptionService.injectable(
        auth: auth,
        now: () => now,
        loadPlatformSubscriptions: (_) async => [],
        loadUserData: (_) async => {
          'isPremium': false,
          'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 30))),
          'downloadedRecipeIds': List.generate(SubscriptionService.maxFreeDownloads, (i) => 'r$i'),
        },
      );

      expect(await service.trackDownload('new_recipe'), isFalse);
    });

    test('trackDownload appends id when free user has remaining slots', () async {
      final appended = <String>[];
      final service = SubscriptionService.injectable(
        auth: auth,
        now: () => now,
        loadPlatformSubscriptions: (_) async => [],
        loadUserData: (_) async => {
          'isPremium': false,
          'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 30))),
          'downloadedRecipeIds': ['r1'],
        },
        appendDownloadedRecipeId: (_, recipeId) async => appended.add(recipeId),
      );

      final allowed = await service.trackDownload('r2');
      expect(allowed, isTrue);
      expect(appended, ['r2']);
    });

    test('canUseFeature recipe_download uses remaining slots for free users', () async {
      final service = SubscriptionService.injectable(
        auth: auth,
        now: () => now,
        loadPlatformSubscriptions: (_) async => [],
        loadUserData: (_) async => {
          'isPremium': false,
          'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 30))),
          'downloadedRecipeIds': ['r1'],
        },
      );

      expect(await service.canUseFeature('recipe_download'), isTrue);
      expect(await service.canUseFeature('image_recognition'), isFalse);
      expect(await service.canUseFeature('unknown_feature'), isTrue);
    });

    test('hasNutritionistAccess true for own profile and active subscription', () async {
      final uid = auth.currentUser!.uid;
      final serviceOwn = SubscriptionService.injectable(
        auth: auth,
        now: () => now,
      );
      expect(await serviceOwn.hasNutritionistAccess(uid), isTrue);

      final serviceOther = SubscriptionService.injectable(
        auth: auth,
        now: () => now,
        loadNutritionistSubscriptions: (_, __) async => [
          {'expiryDate': Timestamp.fromDate(now.add(const Duration(days: 2)))}
        ],
      );
      expect(await serviceOther.hasNutritionistAccess('nut_2'), isTrue);
    });
  });
}
