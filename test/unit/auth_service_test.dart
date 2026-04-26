import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:hidden_pantry_app/core/services/auth_service.dart';

void main() {
  group('AuthService Tests', () {
    late MockFirebaseAuth mockAuth;
    late AuthService authService;

    setUp(() {
      mockAuth = MockFirebaseAuth();
      authService = AuthService(auth: mockAuth);
    });

    test('registerWithEmail should create a new user', () async {
      final email = 'newuser@example.com';
      final password = 'password123';

      final userCredential = await authService.registerWithEmail(email, password);

      expect(userCredential?.user, isNotNull);
      expect(userCredential?.user!.email, email);
    });

    test('loginWithEmail should sign in an existing user', () async {
      final email = 'existing@example.com';
      final password = 'password123';
      
      // Pre-seed a user
      await mockAuth.createUserWithEmailAndPassword(email: email, password: password);
      
      final userCredential = await authService.loginWithEmail(email, password);

      expect(userCredential?.user, isNotNull);
      expect(userCredential?.user!.email, email);
      expect(authService.currentUser, isNotNull);
    });

    test('signOut should clear the current user', () async {
      // Sign in first
      await mockAuth.signInWithEmailAndPassword(email: 'test@ex.com', password: 'pw');
      expect(authService.currentUser, isNotNull);

      await authService.signOut();
      expect(authService.currentUser, isNull);
    });

    test('currentUser should return the currently signed-in user', () async {
      expect(authService.currentUser, isNull);
      
      // Await the async sign-in before asserting
      await mockAuth.signInWithEmailAndPassword(email: 'test@ex.com', password: 'pw');
      
      expect(authService.currentUser, isNotNull);
    });
  });
}
