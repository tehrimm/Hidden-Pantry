import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hidden_pantry_app/core/services/auth_service.dart';
import 'package:hidden_pantry_app/features/auth/screens/login_user.dart';
import '../../functional/mock_firebase.dart';

class MockAuthService extends Mock implements AuthService {}

void main() {
  setUpAll(() async {
    setupFirebaseAuthMocks();
    await Firebase.initializeApp();
  });

  testWidgets('Auth folder: UserLoginScreen renders and shows Login button', (WidgetTester tester) async {
    final mockAuth = MockAuthService();
    await tester.pumpWidget(MaterialApp(home: UserLoginScreen(authService: mockAuth)));
    expect(find.byType(UserLoginScreen), findsOneWidget);
    expect(find.text('Login'), findsWidgets);
  });
}

