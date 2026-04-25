import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/services/chat_encryption_service.dart';

import '../functional/mock_firebase.dart';

void main() {
  setUpAll(() async {
    setupFirebaseAuthMocks();
    await Firebase.initializeApp();
  });

  group('ChatEncryptionService', () {
    test('factory returns singleton instance', () {
      final first = ChatEncryptionService();
      final second = ChatEncryptionService();
      expect(identical(first, second), isTrue);
    });

    test('decryptMessage returns plain text when not encrypted', () async {
      final service = ChatEncryptionService();
      final result = await service.decryptMessage({
        'isEncrypted': 'false',
        'text': 'hello world',
      });
      expect(result, 'hello world');
    });

    test('decryptMessage returns empty string when text missing and not encrypted', () async {
      final service = ChatEncryptionService();
      final result = await service.decryptMessage({
        'isEncrypted': 'false',
      });
      expect(result, '');
    });

    test('decryptMessage returns no-user error when encrypted payload without auth user', () async {
      final service = ChatEncryptionService();
      final result = await service.decryptMessage({
        'isEncrypted': 'true',
        'cipherText': 'abc',
        'encryptedKey': 'xyz',
      });
      expect(result, '[Error: No User]');
    });

    test('encryptMessage falls back to plain text without auth user', () async {
      final service = ChatEncryptionService();
      final result = await service.encryptMessage('plain text', 'recipient-id');
      expect(result['cipherText'], 'plain text');
      expect(result['isEncrypted'], 'false');
      expect(result.containsKey('encryptedKey'), isFalse);
    });
  });
}
