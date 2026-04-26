import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hidden_pantry_app/features/onboarding/screens/starting_screen.dart';
import 'package:hidden_pantry_app/features/onboarding/screens/loading_one.dart';
import 'package:hidden_pantry_app/features/auth/screens/login_user.dart';
import 'mock_firebase.dart';
import 'test_utils.dart';

void main() {
  setUpAll(() async {
    setupFirebaseAuthMocks();
    await Firebase.initializeApp();
    setUpNetworkImageMock();
  });

  Widget wrap(Widget child) => MaterialApp(
    home: child,
    routes: {
      '/login': (_) => const UserLoginScreen(),
    },
  );

  group('Authentication & Onboarding Journey Functional Tests', () {
    testWidgets('StartingScreen displays logo and transitions (timer)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(StartingScreen(
        firestore: MockFirebaseFirestore(),
      )));
      await tester.pump();

      // Check for elements that should be visible initially (assuming images are mocked)
      expect(find.byType(Image), findsWidgets);

      // Wait for splash timer (4 seconds)
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // After splash, it should navigate to MainNavigationShell (if logged in) or LoadingOne (if not)
      // Since mockAuth state varies, we just verify it moved away from StartingScreen
      expect(find.byType(StartingScreen), findsNothing);
    });

    testWidgets('LoadingOne displays core value proposition', (tester) async {
      await tester.pumpWidget(wrap(const LoadingOne()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Share Your\nRecipes'), findsWidgets);
      expect(find.byType(Image), findsWidgets);
    });
  });
}
