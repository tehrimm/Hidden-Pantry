import 'package:flutter_test/flutter_test.dart';

class IdleSession {
  DateTime lastActivity;
  final Duration timeout;
  IdleSession({required this.lastActivity, required this.timeout});
  bool isActiveAt(DateTime now) {
    return now.difference(lastActivity) < timeout;
  }
  void touch(DateTime now) {
    lastActivity = now;
  }
}

void main() {
  group('Integration: Session idle timeout auto-logout', () {
    test('Expires after idle timeout and resets on activity', () {
      final t0 = DateTime(2026, 2, 2, 14, 0, 0);
      final s = IdleSession(lastActivity: t0, timeout: const Duration(minutes: 15));
      expect(s.isActiveAt(t0.add(const Duration(minutes: 10))), true);
      expect(s.isActiveAt(t0.add(const Duration(minutes: 16))), false);
      s.touch(t0.add(const Duration(minutes: 16)));
      expect(s.isActiveAt(t0.add(const Duration(minutes: 20))), true);
    });
  });
}

