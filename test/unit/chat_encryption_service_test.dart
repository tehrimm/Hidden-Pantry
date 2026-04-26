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

  });
}
