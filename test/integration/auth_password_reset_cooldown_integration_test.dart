import 'package:flutter_test/flutter_test.dart';

class ResetCooldown {
  final Duration cooldown;
  final Map<String, DateTime> _last = {};
  ResetCooldown(this.cooldown);
  bool canRequest(String email, DateTime now) {
    final key = email.trim().toLowerCase();
    final prev = _last[key];
    if (prev == null) {
      _last[key] = now;
      return true;
    }
    if (now.difference(prev) >= cooldown) {
      _last[key] = now;
      return true;
    }
    return false;
  }
}

void main() {
  group('Integration: Password reset cooldown', () {
    test('Cooldown enforced per email case-insensitively', () {
      final m = ResetCooldown(const Duration(seconds: 60));
      final t0 = DateTime(2026, 2, 1, 10, 0, 0);
      final ok1 = m.canRequest('User@Email.com', t0);
      final no1 = m.canRequest('user@email.com', t0.add(const Duration(seconds: 30)));
      final ok2 = m.canRequest('user@email.com', t0.add(const Duration(seconds: 61)));
      expect(ok1, true);
      expect(no1, false);
      expect(ok2, true);
    });
  });
}

