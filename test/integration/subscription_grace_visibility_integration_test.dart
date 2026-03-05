import 'package:flutter_test/flutter_test.dart';

enum SubStatus { active, canceled }

bool visibleWithGrace({
  required int minTier,
  required int userTier,
  required SubStatus status,
  required DateTime now,
  required DateTime? graceUntil,
}) {
  if (userTier < minTier) return false;
  if (status == SubStatus.active) return true;
  if (graceUntil == null) return false;
  return now.isBefore(graceUntil) || now.isAtSameMomentAs(graceUntil);
}

void main() {
  group('Integration: Subscription grace visibility', () {
    test('Content remains visible within grace, hides after', () {
      final now = DateTime(2026, 3, 1, 12);
      final until = now.add(const Duration(days: 3));
      final inside = visibleWithGrace(
        minTier: 1,
        userTier: 1,
        status: SubStatus.canceled,
        now: now,
        graceUntil: until,
      );
      expect(inside, true);
      final after = visibleWithGrace(
        minTier: 1,
        userTier: 1,
        status: SubStatus.canceled,
        now: until.add(const Duration(minutes: 1)),
        graceUntil: until,
      );
      expect(after, false);
    });
  });
}

