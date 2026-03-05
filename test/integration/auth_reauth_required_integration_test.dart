import 'package:flutter_test/flutter_test.dart';

class ReauthPolicy {
  final Duration maxAge;
  ReauthPolicy(this.maxAge);
  bool requiresReauth(DateTime lastAuthAt, DateTime now) {
    return now.difference(lastAuthAt) > maxAge;
  }
}

void main() {
  group('Integration: Reauth requirement on sensitive actions', () {
    test('Requires reauth when last auth older than policy window', () {
      final p = ReauthPolicy(const Duration(minutes: 15));
      final t0 = DateTime(2026, 2, 2, 12, 0, 0);
      final ok = p.requiresReauth(t0, t0.add(const Duration(minutes: 10)));
      final need = p.requiresReauth(t0, t0.add(const Duration(minutes: 16)));
      expect(ok, false);
      expect(need, true);
    });
  });
}

