import 'package:flutter_test/flutter_test.dart';

class Token {
  final DateTime issuedAt;
  final Duration ttl;
  Token(this.issuedAt, this.ttl);
  DateTime get expiresAt => issuedAt.add(ttl);
}

class SessionManager {
  final Duration refreshThreshold;
  SessionManager(this.refreshThreshold);
  bool shouldRefresh(Token t, DateTime now) {
    final remaining = t.expiresAt.difference(now);
    return remaining <= refreshThreshold && remaining > Duration.zero;
  }
  bool isValid(Token t, DateTime now) => now.isBefore(t.expiresAt);
}

void main() {
  group('Integration: Session refresh and expiry handling', () {
    test('Refresh when near expiry and valid before expiration', () {
      final now = DateTime(2026, 2, 1, 12, 0, 0);
      final t = Token(now, const Duration(minutes: 30));
      final m = SessionManager(const Duration(minutes: 5));
      final near = now.add(const Duration(minutes: 26));
      final far = now.add(const Duration(minutes: 10));
      expect(m.shouldRefresh(t, far), false);
      expect(m.shouldRefresh(t, near), true);
      expect(m.isValid(t, near), true);
      final after = now.add(const Duration(minutes: 31));
      expect(m.isValid(t, after), false);
    });
  });
}

