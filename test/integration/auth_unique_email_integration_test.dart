import 'package:flutter_test/flutter_test.dart';

class EmailRegistry {
  final Set<String> _emails = {};
  bool register(String email) {
    final key = email.trim().toLowerCase();
    if (_emails.contains(key)) return false;
    _emails.add(key);
    return true;
  }
}

void main() {
  group('Integration: Unique email registration', () {
    test('Rejects duplicate emails case-insensitively', () {
      final r = EmailRegistry();
      expect(r.register('User@Example.com'), true);
      expect(r.register('user@example.com'), false);
    });
  });
}

