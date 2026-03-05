import 'package:flutter_test/flutter_test.dart';

bool canViewContent({
  required int minTier, // 0..3
  required int userTier, // 0..3
}) {
  return userTier >= minTier;
}

void main() {
  group('Business: Content gating by tier', () {
    test('Free content visible to all', () {
      expect(canViewContent(minTier: 0, userTier: 0), true);
      expect(canViewContent(minTier: 0, userTier: 1), true);
      expect(canViewContent(minTier: 0, userTier: 3), true);
    });
    test('Silver content requires tier >= 1', () {
      expect(canViewContent(minTier: 1, userTier: 0), false);
      expect(canViewContent(minTier: 1, userTier: 1), true);
      expect(canViewContent(minTier: 1, userTier: 2), true);
    });
    test('Gold content requires tier >= 2', () {
      expect(canViewContent(minTier: 2, userTier: 1), false);
      expect(canViewContent(minTier: 2, userTier: 2), true);
      expect(canViewContent(minTier: 2, userTier: 3), true);
    });
    test('Platinum content requires tier 3', () {
      expect(canViewContent(minTier: 3, userTier: 2), false);
      expect(canViewContent(minTier: 3, userTier: 3), true);
    });
  });
}

