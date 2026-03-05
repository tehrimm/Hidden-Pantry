import 'package:flutter_test/flutter_test.dart';

class LockoutManager {
  final int maxFailures;
  final Duration window;
  final Duration lockDuration;
  DateTime? _lockUntil;
  final List<DateTime> _failures = [];
  LockoutManager({required this.maxFailures, required this.window, required this.lockDuration});
  bool get isLocked => _lockUntil != null && DateTime.now().isBefore(_lockUntil!);
  bool isLockedAt(DateTime now) => _lockUntil != null && now.isBefore(_lockUntil!);
  void recordFailure(DateTime now) {
    _failures.removeWhere((t) => now.difference(t) > window);
    _failures.add(now);
    if (_failures.length >= maxFailures) {
      _lockUntil = now.add(lockDuration);
      _failures.clear();
    }
  }
  void recordSuccess() {
    _failures.clear();
    _lockUntil = null;
  }
}

void main() {
  group('Integration: Auth login lockout and cooldown', () {
    test('Locks after consecutive failures and unlocks after duration', () {
      final m = LockoutManager(maxFailures: 3, window: const Duration(minutes: 15), lockDuration: const Duration(minutes: 10));
      DateTime t = DateTime(2026, 1, 1, 12, 0, 0);
      m.recordFailure(t);
      m.recordFailure(t.add(const Duration(minutes: 1)));
      expect(m.isLockedAt(t), false);
      m.recordFailure(t.add(const Duration(minutes: 2)));
      expect(m.isLockedAt(t.add(const Duration(minutes: 2))), true);
      expect(m.isLockedAt(t.add(const Duration(minutes: 11))), true);
      expect(m.isLockedAt(t.add(const Duration(minutes: 13))), false);
      m.recordSuccess();
      expect(m.isLockedAt(t.add(const Duration(minutes: 13))), false);
    });
  });
}
