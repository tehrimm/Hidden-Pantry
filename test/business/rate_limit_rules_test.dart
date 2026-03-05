import 'package:flutter_test/flutter_test.dart';

bool allowAction({
  required DateTime now,
  required DateTime? lastTime,
  Duration cooldown = const Duration(seconds: 1),
}) {
  if (lastTime == null) return true;
  return now.difference(lastTime) >= cooldown;
}

void main() {
  group('Business: Cooldown / rate-limit rules', () {
    test('Allows when no last time', () {
      final ok = allowAction(now: DateTime(2024, 1, 1, 12), lastTime: null);
      expect(ok, true);
    });
    test('Blocks inside cooldown window', () {
      final now = DateTime(2024, 1, 1, 12, 0, 1, 500);
      final last = DateTime(2024, 1, 1, 12, 0, 1, 0);
      final ok = allowAction(now: now, lastTime: last, cooldown: const Duration(milliseconds: 600));
      expect(ok, false);
    });
    test('Allows after cooldown passes', () {
      final now = DateTime(2024, 1, 1, 12, 0, 2, 0);
      final last = DateTime(2024, 1, 1, 12, 0, 1, 0);
      final ok = allowAction(now: now, lastTime: last, cooldown: const Duration(milliseconds: 900));
      expect(ok, true);
    });
  });
}

