import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hidden_pantry_app/core/services/chat_encryption_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import '../functional/mock_firebase.dart';

void main() {
  setUpAll(() async {
    setupFirebaseAuthMocks();
    await Firebase.initializeApp();
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('ChatEncryptionService Unit Tests', () {
    test('Initialization does not crash', () {
      final service = ChatEncryptionService();
      expect(service, isNotNull);
    });

    // Test the parsing string logic that is public or exposed via reflection if possible, 
    // or we can test the public surface:
    test('encryptMessage handling gracefully with no keys', () async {
      final mockAuth = MockFirebaseAuth();
      final service = ChatEncryptionService(auth: mockAuth);
      
      final encrypted = await service.encryptMessage('secret', 'targetUser');
      
      expect(encrypted is Map, isTrue);
      expect(encrypted['cipherText'], 'secret');
      expect(encrypted['isEncrypted'], 'false');
    });
  });
}
