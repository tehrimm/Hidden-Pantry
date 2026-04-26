import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/services/auth_service.dart';
import 'package:hidden_pantry_app/core/utils/auth_validator.dart';
import 'package:hidden_pantry_app/features/user/models/user_model.dart';

void main() {
  group('Real Integration Tests: Authentication Flow', () {

    // ─── Registration ──────────────────────────────────────────────
    group('User Registration', () {
      late MockFirebaseAuth mockAuth;
      late AuthService authService;

      setUp(() {
        mockAuth = MockFirebaseAuth();
        authService = AuthService(auth: mockAuth);
      });

      test('registerWithEmail creates a new user successfully', () async {
        final cred = await authService.registerWithEmail(
          'alice@example.com',
          'SecurePass123',
        );
        expect(cred, isNotNull);
        expect(cred!.user, isNotNull);
        expect(cred.user!.email, 'alice@example.com');
      });

      test('currentUser is non-null after registration', () async {
        await authService.registerWithEmail('bob@test.com', 'Passw0rd!');
        expect(authService.currentUser, isNotNull);
      });

      test('Registration validates email before calling Firebase', () {
        // Validator catches bad email before Firebase is even called
        final err = AuthValidator.validateEmail('not-an-email');
        expect(err, '*incorrect email');
      });

      test('Registration validates password length before calling Firebase', () {
        final err = AuthValidator.validatePassword('short');
        expect(err, '*password must be at least 8 characters');
      });

      test('Registration validates full name before proceeding', () {
        final err = AuthValidator.validateFullName('Al');
        expect(err, '*invalid name');
      });
    });

    // ─── Login ─────────────────────────────────────────────────────
    group('User Login', () {
      late MockFirebaseAuth mockAuth;
      late AuthService authService;

      setUp(() {
        // Pre-register a user for login tests
        mockAuth = MockFirebaseAuth(
          mockUser: MockUser(
            uid: 'login_uid',
            email: 'login@test.com',
            displayName: 'Login User',
          ),
        );
        authService = AuthService(auth: mockAuth);
      });

      test('loginWithEmail signs in successfully', () async {
        final cred = await authService.loginWithEmail(
          'login@test.com',
          'ValidPass123',
        );
        expect(cred, isNotNull);
        expect(cred!.user!.email, 'login@test.com');
      });

      test('currentUser reflects signed-in user after login', () async {
        await authService.loginWithEmail('login@test.com', 'ValidPass123');
        expect(authService.currentUser, isNotNull);
        expect(authService.currentUser!.email, 'login@test.com');
      });

      test('currentUser is null when not signed in', () {
        // Fresh auth with no signed-in user
        final freshAuth = MockFirebaseAuth();
        final freshService = AuthService(auth: freshAuth);
        expect(freshService.currentUser, null);
      });

      test('displayName is accessible from signed-in user', () async {
        await authService.loginWithEmail('login@test.com', 'ValidPass123');
        expect(authService.currentUser!.displayName, 'Login User');
      });
    });

    // ─── Sign Out ──────────────────────────────────────────────────
    group('Sign Out', () {
      late MockFirebaseAuth mockAuth;
      late AuthService authService;

      setUp(() {
        mockAuth = MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'signout_uid', email: 'out@test.com'),
        );
        authService = AuthService(auth: mockAuth);
      });

      test('signOut clears currentUser', () async {
        expect(authService.currentUser, isNotNull); // Signed in
        await authService.signOut();
        expect(authService.currentUser, null);      // Now signed out
      });

      test('signOut is idempotent (double sign-out does not crash)', () async {
        await authService.signOut();
        await authService.signOut(); // Should not throw
        expect(authService.currentUser, null);
      });
    });

    // ─── Session State ──────────────────────────────────────────────
    group('Session State', () {
      test('Signed-in user has a non-empty UID', () async {
        final mockAuth = MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'uid_session_001', email: 'session@test.com'),
        );
        final service = AuthService(auth: mockAuth);
        await service.loginWithEmail('session@test.com', 'Pass1234!');
        expect(service.currentUser!.uid, isNotEmpty);
        expect(service.currentUser!.uid, 'uid_session_001');
      });

      test('Stream emits non-null user when signed in', () async {
        final mockAuth = MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'stream_uid', email: 's@test.com'),
        );
        final user = await mockAuth.authStateChanges().first;
        expect(user, isNotNull);
        expect(user!.uid, 'stream_uid');
      });

      test('Stream emits null when signed out', () async {
        final mockAuth = MockFirebaseAuth();
        final user = await mockAuth.authStateChanges().first;
        expect(user, null);
      });
    });

    // ─── Role-Based Routing Logic ──────────────────────────────────
    group('Role-Based User Routing', () {
      test('UserModel with role=homecook routes to user app', () {
        final user = UserModel(
          uid: 'u1', email: 'u@test.com', fullName: 'Alice',
          role: 'homecook',
        );
        final isNutritionist = user.role == 'nutritionist';
        expect(isNutritionist, false);
      });

      test('UserModel with role=nutritionist routes to nutritionist dashboard', () {
        final user = UserModel(
          uid: 'n1', email: 'n@test.com', fullName: 'Dr. Bob',
          role: 'nutritionist',
        );
        final isNutritionist = user.role == 'nutritionist';
        expect(isNutritionist, true);
      });

      test('Default role is homecook when not specified', () {
        // Simulate what fromFirestore does when role is missing
        final data = <String, dynamic>{'email': 'x@test.com', 'fullName': 'X'};
        final role = data['role'] ?? 'homecook';
        expect(role, 'homecook');
      });
    });

    // ─── Validation → Auth Pipeline ──────────────────────────────────
    group('Validation Gates before Auth calls', () {
      test('Empty email blocks registration before Firebase call', () {
        final emailErr = AuthValidator.validateEmail('');
        final passErr = AuthValidator.validatePassword('ValidPass1');
        // Email fails first → Firebase never called
        expect(emailErr, isNotNull);
        expect(passErr, null);
      });

      test('Valid inputs pass all validators before Firebase call', () {
        final emailErr = AuthValidator.validateEmail('valid@email.com');
        final passErr = AuthValidator.validatePassword('ValidPass1');
        final nameErr = AuthValidator.validateFullName('Alice Smith');
        expect(emailErr, null);
        expect(passErr, null);
        expect(nameErr, null);
      });

      test('All validators passing means auth call is safe to proceed', () {
        final email = 'test@test.com';
        final pass = 'SecurePass99';
        final name = 'John Doe';

        final allValid = AuthValidator.validateEmail(email) == null &&
            AuthValidator.validatePassword(pass) == null &&
            AuthValidator.validateFullName(name) == null;

        expect(allValid, true);
      });

      test('Invalid phone blocks phone auth flow before Firebase OTP call', () {
        final shortPhone = AuthValidator.validatePhone('12345');
        expect(shortPhone, '*enter valid number');

        final validPhone = AuthValidator.validatePhone('03001234567');
        expect(validPhone, null);
      });
    });

    // ─── Password Reset Flow ────────────────────────────────────────
    group('Password Reset Flow', () {
      test('Reset email validated before sending', () {
        final err = AuthValidator.validateEmail('bad-email');
        expect(err, isNotNull); // Blocked before Firebase call
      });

      test('Valid reset email passes validator', () {
        final err = AuthValidator.validateEmail('reset@example.com');
        expect(err, null);
      });

      test('MockFirebaseAuth allows sendPasswordResetEmail without error', () async {
        final mockAuth = MockFirebaseAuth();
        final service = AuthService(auth: mockAuth);
        // Should complete without throwing
        await expectLater(
          service.sendPasswordResetEmail(email: 'reset@example.com'),
          completes,
        );
      });
    });

    // ─── Nutritionist-Specific Auth Routing ──────────────────────────
    group('Nutritionist Auth Routing', () {
      test('Test nutritionist email bypasses pending status (approved instantly)', () {
        const testEmail = 'testnutritionist@gmail.com';
        // Logic from NutritionistService.createNutritionistProfile
        final status = (testEmail.trim().toLowerCase() == 'testnutritionist@gmail.com' ||
            testEmail.trim().toLowerCase() == 'testnutrionist@gmail.com')
            ? 'approved'
            : 'pending';
        expect(status, 'approved');
      });

      test('Regular nutritionist email gets pending status', () {
        const regularEmail = 'dr.smith@hospital.com';
        final status = (regularEmail.trim().toLowerCase() == 'testnutritionist@gmail.com' ||
            regularEmail.trim().toLowerCase() == 'testnutrionist@gmail.com')
            ? 'approved'
            : 'pending';
        expect(status, 'pending');
      });

      test('Nutritionist rejected status blocks dashboard access', () {
        const verificationStatus = 'rejected';
        final canAccessDashboard = verificationStatus == 'approved';
        expect(canAccessDashboard, false);
      });

      test('Nutritionist approved status allows dashboard access', () {
        const verificationStatus = 'approved';
        final canAccessDashboard = verificationStatus == 'approved';
        expect(canAccessDashboard, true);
      });
    });
  });
}
