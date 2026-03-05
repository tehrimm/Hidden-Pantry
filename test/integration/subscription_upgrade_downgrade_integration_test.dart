import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/state/state_management.dart';

void main() {
  group('Integration: Subscription upgrade/downgrade', () {
    test('Changes active tier', () {
      final s = SubscriptionController();
      expect(s.activeTier, 'Silver');
      s.upgradeTier();
      expect(s.activeTier, 'Gold');
      s.downgradeTier();
      expect(s.activeTier, 'Silver');
    });
  });
}

