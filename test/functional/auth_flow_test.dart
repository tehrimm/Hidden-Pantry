
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hidden_pantry_app/features/auth/screens/signup_user.dart';
import 'package:hidden_pantry_app/features/recipes/screens/allergies.dart';
import 'package:hidden_pantry_app/core/widgets/main_navigation_shell.dart';
import 'package:hidden_pantry_app/features/user/screens/user_profile.dart';
import 'package:hidden_pantry_app/features/onboarding/screens/starting_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'test_utils.dart';
import 'mock_firebase.dart';

// Using MockAuthService, MockUserService, FakeUser, and FakeUserCredential from test_utils.dart
class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

void main() {
  late MockAuthService mockAuthService;
  late MockUserService mockUserService;

  setUpAll(() async {
    setupFirebaseAuthMocks();
    await Firebase.initializeApp();
  });

  setUp(() {
    mockAuthService = MockAuthService();
    mockUserService = MockUserService();
  });

  Widget createTestWidget(Widget child) {
    return MaterialApp(
      home: child,
      // Provide a dummy theme if needed
    );
  }

  testWidgets('Auth Flow: Signup -> Allergies -> Home -> Logout', (WidgetTester tester) async {
    final fakeUserCredential = FakeUserCredential();

    // 1. Signup Screen setup
    when(mockAuthService.registerWithEmail(
      email: 'test@gmail.com',
      password: 'Password123!',
    )).thenAnswer((_) async => fakeUserCredential);

    when(mockUserService.upsertCurrentUserProfile(
      fullName: 'Test User',
      phoneNumber: '+923001234567',
      allergies: [],
    )).thenAnswer((_) async {});

    await tester.pumpWidget(createTestWidget(SignupUserScreen(
      authService: mockAuthService,
      userService: mockUserService,
    )));

    // Fill fields
    await tester.enterText(find.byType(TextField).at(0), 'Test User'); // Name
    await tester.enterText(find.byType(TextField).at(1), 'test');      // Gmail username
    await tester.enterText(find.byType(TextField).at(2), '3001234567'); // Phone
    await tester.enterText(find.byType(TextField).at(3), 'Password123!'); // Password

    // Tap Register
    await tester.tap(find.widgetWithText(GestureDetector, 'Register'));
    await tester.pumpAndSettle();

    // 2. Allergies Screen
    expect(find.byType(AllergiesScreen), findsOneWidget);
    
    when(mockUserService.updateAllergies(['Fish'])).thenAnswer((_) async {});

    // Select an allergy (e.g., Fish)
    await tester.tap(find.text('Fish'));
    await tester.pump();

    // Tap Continue
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    // 3. Home Navigation (Normally navigates to MainNavigationShell)
    // Note: In tests, navigation might be complex if it depends on real Firebase.
    // For this functional test, we verify the screen transition.
    expect(find.byType(MainNavigationShell), findsOneWidget);

    // 4. Navigate to Profile
    // The MainNavigationShell contains HomeScreen which has the avatar
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(UserProfileScreen), findsOneWidget);
    // 5. Logout - tap the GestureDetector that wraps the Logout button
    final logoutText = find.text('Logout', skipOffstage: false);
    await tester.ensureVisible(logoutText);
    await tester.pump();
    // Tap the ancestor GestureDetector, not just the Text widget
    final logoutButton = find.ancestor(
      of: logoutText,
      matching: find.byType(GestureDetector),
    ).first;
    await tester.tap(logoutButton);
    // Navigation is immediate (signOut fires in background), so one frame is enough.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify we transitioned to StartingScreen
    expect(find.byType(StartingScreen), findsOneWidget);

    // Drain all pending timers to prevent 'Timer is still pending' assertion:
    // - signOut().timeout(3s) from _logout()
    // - StartingScreen knife animation timer (1s)
    // - StartingScreen nav timer (4s)
    // We go past all of them in one shot.
    await tester.pump(const Duration(seconds: 5));
  });
}
