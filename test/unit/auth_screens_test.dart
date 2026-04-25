import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:hidden_pantry_app/core/services/auth_service.dart';
import 'package:hidden_pantry_app/features/auth/screens/login_user.dart';
import 'package:hidden_pantry_app/features/auth/screens/signup_user.dart';
import 'package:hidden_pantry_app/features/auth/screens/forget_password_email.dart';
import 'package:hidden_pantry_app/features/auth/screens/forget_password_phone.dart';
import 'package:firebase_core/firebase_core.dart';
import '../functional/mock_firebase.dart';
import '../functional/test_utils.dart' show setUpNetworkImageMock, MockUserService;

// Generate Mock classes if needed, or define manually
class MockAuthService extends Mock implements AuthService {}

void main() {
  late MockAuthService mockAuthService;

  setUpAll(() async {
    setupFirebaseAuthMocks();
    await Firebase.initializeApp();
    setUpNetworkImageMock();
  });

  setUp(() {
    mockAuthService = MockAuthService();
  });

  Widget createWidgetForTesting({required Widget child}) {
    return MaterialApp(
      home: child,
    );
  }

  group('UserLoginScreen Validation Tests', () {
    testWidgets('shows error messages for empty fields when Login button is pressed', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetForTesting(
        child: UserLoginScreen(authService: mockAuthService),
      ));

      // Initially no errors
      expect(find.text('*field is required'), findsNothing);
      expect(find.text('*password field is required'), findsNothing);

      // Find and tap login button
      await tester.tap(find.text('Login').last);
      await tester.pump(); // Trigger setState

      // Should show validation errors
      expect(find.text('*field is required'), findsOneWidget);
      expect(find.text('*password field is required'), findsOneWidget);
    });

    testWidgets('shows error for weak password', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetForTesting(
        child: UserLoginScreen(authService: mockAuthService),
      ));

      final emailField = find.byType(TextField).first;
      final passField = find.byType(TextField).last;

      await tester.enterText(emailField, 'testuser');
      await tester.enterText(passField, '123'); // Too short
      
      await tester.tap(find.text('Login').last);
      await tester.pump();

      expect(find.text('*password must be at least 8 characters'), findsOneWidget);
    });
  });

  group('SignupUserScreen Validation Tests', () {
    testWidgets('shows multiple error messages for invalid registration data', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidgetForTesting(
        child: SignupUserScreen(
          authService: mockAuthService,
          userService: MockUserService(),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      // Tap register with empty fields
      expect(find.text('Register'), findsWidgets);
      await tester.tap(find.text('Register').last);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('*field is required'), findsNWidgets(2)); // Name and Email
      expect(find.text('*phone number is required'), findsOneWidget);
    });

    testWidgets('renders signup screen successfully', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidgetForTesting(
        child: SignupUserScreen(
          authService: mockAuthService,
          userService: MockUserService(),
        ),
      ));
      await tester.pump();
      expect(find.byType(SignupUserScreen), findsOneWidget);
    });
  });

  group('ForgetPasswordEmailScreen Validation Tests', () {
    testWidgets('shows error for empty email', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidgetForTesting(
        child: const ForgetPasswordEmailScreen(),
      ));

      await tester.ensureVisible(find.text('Send Link').last);
      await tester.tap(find.text('Send Link').last);
      await tester.pump();

      expect(find.text('Email is required'), findsOneWidget);
    });
  });

  group('ForgetPasswordPhoneScreen Validation Tests', () {
    testWidgets('shows error for invalid phone number', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(createWidgetForTesting(
        child: ForgetPasswordPhoneScreen(authService: mockAuthService),
      ));

      await tester.enterText(find.byType(TextField), '123'); // Too short
      await tester.tap(find.text('Next'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('*enter valid number'), findsOneWidget);
    });
  });
}
