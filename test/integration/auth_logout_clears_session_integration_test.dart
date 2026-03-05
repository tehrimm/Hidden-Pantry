import 'package:flutter_test/flutter_test.dart';

class SessionStore {
  String? token;
  bool get isAuthenticated => token != null && token!.isNotEmpty;
  void login(String t) {
    token = t;
  }
  void logout() {
    token = null;
  }
}

void main() {
  group('Integration: Logout clears session state', () {
    test('Login sets token and logout clears it', () {
      final s = SessionStore();
      expect(s.isAuthenticated, false);
      s.login('abc123');
      expect(s.isAuthenticated, true);
      s.logout();
      expect(s.isAuthenticated, false);
    });
  });
}

