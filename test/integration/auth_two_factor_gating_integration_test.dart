import 'package:flutter_test/flutter_test.dart';

class User2FA {
  final bool isLoggedIn;
  final bool twoFactorEnabled;
  final bool twoFactorVerified;
  User2FA({required this.isLoggedIn, required this.twoFactorEnabled, required this.twoFactorVerified});
}

bool canDoSensitive(User2FA u) {
  if (!u.isLoggedIn) return false;
  if (!u.twoFactorEnabled) return true;
  return u.twoFactorVerified;
}

void main() {
  group('Integration: Two-factor gating for sensitive actions', () {
    test('Requires verification when 2FA enabled, bypass when disabled', () {
      final loggedNo2FA = User2FA(isLoggedIn: true, twoFactorEnabled: false, twoFactorVerified: false);
      final logged2faNotVerified = User2FA(isLoggedIn: true, twoFactorEnabled: true, twoFactorVerified: false);
      final logged2faVerified = User2FA(isLoggedIn: true, twoFactorEnabled: true, twoFactorVerified: true);
      final notLogged = User2FA(isLoggedIn: false, twoFactorEnabled: true, twoFactorVerified: true);
      expect(canDoSensitive(loggedNo2FA), true);
      expect(canDoSensitive(logged2faNotVerified), false);
      expect(canDoSensitive(logged2faVerified), true);
      expect(canDoSensitive(notLogged), false);
    });
  });
}

