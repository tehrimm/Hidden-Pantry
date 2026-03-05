import 'package:flutter_test/flutter_test.dart';

class UserState {
  final bool emailVerified;
  final bool isLoggedIn;
  const UserState(this.emailVerified, this.isLoggedIn);
}

bool canAccessProtected(UserState u) {
  if (!u.isLoggedIn) return false;
  return u.emailVerified;
}

void main() {
  group('Integration: Email verification gating', () {
    test('Access denied until email verified, then allowed', () {
      final before = UserState(false, true);
      final after = UserState(true, true);
      expect(canAccessProtected(before), false);
      expect(canAccessProtected(after), true);
    });
    test('Access denied when not logged in', () {
      final u = UserState(true, false);
      expect(canAccessProtected(u), false);
    });
  });
}

