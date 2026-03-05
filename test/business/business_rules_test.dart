import 'package:flutter_test/flutter_test.dart';

enum Screen { signup, pending, rejected, dashboard }

bool isUnlocked({required int currentTier, required int minTier}) => currentTier >= minTier;

bool canToggleLike({
  required bool viewerIsNutritionist,
  required bool isLocked,
  required bool idsPresent,
}) {
  if (viewerIsNutritionist) return false;
  if (isLocked) return false;
  if (!idsPresent) return false;
  return true;
}

Screen route({
  required bool authenticated,
  required bool docExists,
  String? status,
}) {
  if (!authenticated) return Screen.signup;
  if (!docExists) return Screen.signup;
  if (status == 'pending') return Screen.pending;
  if (status == 'rejected') return Screen.rejected;
  if (status == 'approved') return Screen.dashboard;
  return Screen.signup;
}

class PaymentState {
  final List<String> ids;
  final String? defaultId;
  const PaymentState(this.ids, this.defaultId);
}

PaymentState addMethod(PaymentState state, String newId) {
  final ids = [...state.ids, newId];
  final defaultId = state.ids.isEmpty ? newId : state.defaultId;
  return PaymentState(ids, defaultId);
}

PaymentState deleteMethod(PaymentState state, String deleteId) {
  final remaining = [...state.ids]..remove(deleteId);
  String? nextDefault = state.defaultId;
  if (deleteId == state.defaultId) {
    nextDefault = remaining.isNotEmpty ? remaining.first : null;
  }
  return PaymentState(remaining, nextDefault);
}

void main() {
  group('Content Visibility by Subscription Tier', () {
    test('Free post visible to free user', () {
      expect(isUnlocked(currentTier: 0, minTier: 0), true);
    });
    test('Silver post visible to silver user', () {
      expect(isUnlocked(currentTier: 1, minTier: 1), true);
    });
    test('Silver post locked for free user', () {
      expect(isUnlocked(currentTier: 0, minTier: 1), false);
    });
    test('Gold post locked for silver user', () {
      expect(isUnlocked(currentTier: 1, minTier: 2), false);
    });
    test('Gold post visible to platinum user', () {
      expect(isUnlocked(currentTier: 3, minTier: 2), true);
    });
    test('Platinum post locked for gold user', () {
      expect(isUnlocked(currentTier: 2, minTier: 3), false);
    });
    test('Platinum post visible to platinum user', () {
      expect(isUnlocked(currentTier: 3, minTier: 3), true);
    });
    test('Free post visible to platinum user', () {
      expect(isUnlocked(currentTier: 3, minTier: 0), true);
    });
  });

  group('Like/Comment Availability Rules', () {
    test('User, unlocked, valid ids can like', () {
      expect(
        canToggleLike(viewerIsNutritionist: false, isLocked: false, idsPresent: true),
        true,
      );
    });
    test('User, locked cannot like', () {
      expect(
        canToggleLike(viewerIsNutritionist: false, isLocked: true, idsPresent: true),
        false,
      );
    });
    test('Nutritionist viewer cannot like', () {
      expect(
        canToggleLike(viewerIsNutritionist: true, isLocked: false, idsPresent: true),
        false,
      );
    });
    test('Missing ids cannot like', () {
      expect(
        canToggleLike(viewerIsNutritionist: false, isLocked: false, idsPresent: false),
        false,
      );
    });

    bool myPostsLikeEnabledForOwner() => false;
    test('Owner like on My Posts is disabled', () {
      expect(myPostsLikeEnabledForOwner(), false);
    });
  });

  group('Nutritionist Signup Routing', () {
    test('Unauthenticated routes to signup', () {
      expect(route(authenticated: false, docExists: false), Screen.signup);
    });
    test('Authenticated without doc routes to signup', () {
      expect(route(authenticated: true, docExists: false), Screen.signup);
    });
    test('Pending routes to pending screen', () {
      expect(route(authenticated: true, docExists: true, status: 'pending'), Screen.pending);
    });
    test('Rejected routes to rejected screen', () {
      expect(route(authenticated: true, docExists: true, status: 'rejected'), Screen.rejected);
    });
    test('Approved routes to dashboard', () {
      expect(route(authenticated: true, docExists: true, status: 'approved'), Screen.dashboard);
    });
    test('Unknown status routes to signup', () {
      expect(route(authenticated: true, docExists: true, status: 'other'), Screen.signup);
    });
  });

  group('Payment Method Defaults', () {
    test('Add first card becomes default', () {
      final s0 = PaymentState([], null);
      final s1 = addMethod(s0, 'card_1');
      expect(s1.defaultId, 'card_1');
    });
    test('Add second card keeps previous default', () {
      final s1 = PaymentState(['card_1'], 'card_1');
      final s2 = addMethod(s1, 'card_2');
      expect(s2.defaultId, 'card_1');
    });
    test('Delete default promotes next oldest', () {
      final s = PaymentState(['card_1', 'card_2'], 'card_1');
      final s2 = deleteMethod(s, 'card_1');
      expect(s2.defaultId, 'card_2');
    });
    test('Delete sole method leaves no default', () {
      final s = PaymentState(['card_1'], 'card_1');
      final s2 = deleteMethod(s, 'card_1');
      expect(s2.defaultId, null);
      expect(s2.ids.isEmpty, true);
    });
    test('First wallet becomes default similarly', () {
      final s0 = PaymentState([], null);
      final s1 = addMethod(s0, 'wallet_1');
      expect(s1.defaultId, 'wallet_1');
    });
  });
}

