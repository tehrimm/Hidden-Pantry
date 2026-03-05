import 'package:flutter_test/flutter_test.dart';

class SubscriptionStub {
  final String status; // active | trialing | canceled | incomplete ...
  final DateTime? expiryDate;
  final int? tierLevel; // 0/1/2/3
  final String? planTitle; // e.g., "Gold Monthly"
  SubscriptionStub({
    required this.status,
    this.expiryDate,
    this.tierLevel,
    this.planTitle,
  });
}

bool _isActive(SubscriptionStub s, DateTime now) {
  if (s.status == 'active' || s.status == 'trialing') return true;
  if (s.expiryDate != null && s.expiryDate!.isAfter(now)) return true;
  return false;
}

int _tierFor(SubscriptionStub s) {
  if (s.tierLevel != null && s.tierLevel! > 0) return s.tierLevel!;
  final title = (s.planTitle ?? '').toLowerCase();
  if (title.contains('platinum')) return 3;
  if (title.contains('gold')) return 2;
  if (title.isNotEmpty) return 1;
  return 1; // default minimal paid tier
}

int chooseHighestTier(List<SubscriptionStub> subs, {DateTime? now}) {
  final n = now ?? DateTime.now();
  int highest = 0;
  for (final s in subs) {
    if (_isActive(s, n)) {
      final t = _tierFor(s);
      if (t > highest) highest = t;
    }
  }
  return highest;
}

void main() {
  group('Business: Subscription tier resolution', () {
    test('No subs => tier 0', () {
      expect(chooseHighestTier([]), 0);
    });

    test('Active overrides expired', () {
      final now = DateTime.now();
      final subs = [
        SubscriptionStub(status: 'active', tierLevel: 1),
        SubscriptionStub(status: 'canceled', tierLevel: 3, expiryDate: now.subtract(const Duration(days: 1))),
      ];
      expect(chooseHighestTier(subs, now: now), 1);
    });

    test('Highest active tier is chosen', () {
      final now = DateTime.now();
      final subs = [
        SubscriptionStub(status: 'active', tierLevel: 1),
        SubscriptionStub(status: 'trialing', tierLevel: 2),
        SubscriptionStub(status: 'canceled', tierLevel: 3, expiryDate: now.add(const Duration(days: 2))),
      ];
      expect(chooseHighestTier(subs, now: now), 3);
    });

    test('Title-based fallback assigns tiers', () {
      final now = DateTime.now();
      final subs = [
        SubscriptionStub(status: 'active', planTitle: 'Gold Monthly'),
        SubscriptionStub(status: 'active', planTitle: 'Platinum Annual'),
      ];
      expect(chooseHighestTier(subs, now: now), 3);
    });

    test('Future expiry without active status still active', () {
      final now = DateTime(2024, 1, 1);
      final subs = [
        SubscriptionStub(status: 'canceled', tierLevel: 2, expiryDate: DateTime(2024, 1, 3)),
      ];
      expect(chooseHighestTier(subs, now: now), 2);
    });
  });
}

