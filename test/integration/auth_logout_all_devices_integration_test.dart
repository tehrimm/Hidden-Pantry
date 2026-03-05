import 'package:flutter_test/flutter_test.dart';

class SessionRegistry {
  final Map<String, Set<String>> _tokens = {};
  void login(String userId, String token) {
    final set = _tokens.putIfAbsent(userId, () => <String>{});
    set.add(token);
  }
  bool isValid(String userId, String token) {
    final set = _tokens[userId];
    if (set == null) return false;
    return set.contains(token);
  }
  void logoutAll(String userId) {
    _tokens[userId] = <String>{};
  }
}

void main() {
  group('Integration: Logout-all devices invalidates sessions', () {
    test('Existing tokens invalid after logout-all', () {
      final r = SessionRegistry();
      r.login('u1', 't1');
      r.login('u1', 't2');
      expect(r.isValid('u1', 't1'), true);
      expect(r.isValid('u1', 't2'), true);
      r.logoutAll('u1');
      expect(r.isValid('u1', 't1'), false);
      expect(r.isValid('u1', 't2'), false);
    });
  });
}

