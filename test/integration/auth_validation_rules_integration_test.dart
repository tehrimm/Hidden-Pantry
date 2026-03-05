import 'package:flutter_test/flutter_test.dart';

bool validEmail(String email) {
  final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  return re.hasMatch(email);
}

bool validPassword(String pwd) {
  if (pwd.length < 8) return false;
  final hasLetter = RegExp(r'[A-Za-z]').hasMatch(pwd);
  final hasDigit = RegExp(r'\d').hasMatch(pwd);
  return hasLetter && hasDigit;
}

void main() {
  group('Integration: Email/password validation rules', () {
    test('Email basic format', () {
      expect(validEmail('user@example.com'), true);
      expect(validEmail('bad@com'), false);
      expect(validEmail('no-at.example.com'), false);
    });
    test('Password complexity', () {
      expect(validPassword('Pass1234'), true);
      expect(validPassword('short1'), false);
      expect(validPassword('allletters'), false);
      expect(validPassword('12345678'), false);
    });
  });
}

