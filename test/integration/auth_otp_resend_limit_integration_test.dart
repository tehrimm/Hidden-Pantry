import 'package:flutter_test/flutter_test.dart';

class OtpLimiter {
  final int maxPerWindow;
  final Duration window;
  final Map<String, List<DateTime>> _reqs = {};
  OtpLimiter(this.maxPerWindow, this.window);
  bool canSend(String phone, DateTime now) {
    final key = phone.replaceAll(RegExp(r'\\s+'), '');
    final list = _reqs[key] ?? [];
    list.removeWhere((t) => now.difference(t) > window);
    if (list.length >= maxPerWindow) {
      _reqs[key] = list;
      return false;
    }
    list.add(now);
    _reqs[key] = list;
    return true;
  }
}

void main() {
  group('Integration: OTP resend limit and cooldown', () {
    test('Limits requests per phone within window and allows after window', () {
      final l = OtpLimiter(3, const Duration(minutes: 5));
      final t0 = DateTime(2026, 2, 2, 10, 0, 0);
      expect(l.canSend('+1 555 000', t0), true);
      expect(l.canSend('+1 555 000', t0.add(const Duration(minutes: 1))), true);
      expect(l.canSend('+1 555 000', t0.add(const Duration(minutes: 2))), true);
      expect(l.canSend('+1 555 000', t0.add(const Duration(minutes: 3))), false);
      expect(l.canSend('+1 555 000', t0.add(const Duration(minutes: 6))), true);
    });
  });
}

