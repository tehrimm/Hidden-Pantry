import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/user/screens/user_network_screen.dart';
import 'test_utils.dart';
import 'mock_firebase.dart';
import 'package:firebase_core/firebase_core.dart';

void main() {
  setUpAll(() async {
    setupFirebaseAuthMocks();
    await Firebase.initializeApp();
    setUpNetworkImageMock();
  });

  Widget wrap(Widget child) {
    return MaterialApp(home: child);
  }

  void setupScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
  }

  void resetScreen(WidgetTester tester) {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  group('User Network Screen Functional Tests', () {
    testWidgets('Renders tabs and title', (tester) async {
      setupScreen(tester);
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(wrap(const UserNetworkScreen(initialIndex: 0)));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('My Network'), findsOneWidget);
      expect(find.text('Following'), findsOneWidget);
      expect(find.text('Followers'), findsOneWidget);
    });

    testWidgets('Following tab shows loading or empty state', (tester) async {
      setupScreen(tester);
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(wrap(const UserNetworkScreen(initialIndex: 0)));
      // First pump — may show CircularProgressIndicator
      await tester.pump(const Duration(milliseconds: 100));

      // Either loading indicator or empty message is acceptable
      final hasLoading = tester.any(find.byType(CircularProgressIndicator));
      final hasEmpty = tester.any(find.textContaining('following'));
      expect(hasLoading || hasEmpty, isTrue);
    });

    testWidgets('Followers tab shows loading or empty state', (tester) async {
      setupScreen(tester);
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(wrap(const UserNetworkScreen(initialIndex: 1)));
      await tester.pump(const Duration(milliseconds: 100));

      final hasLoading = tester.any(find.byType(CircularProgressIndicator));
      final hasEmpty = tester.any(find.textContaining('followers'));
      expect(hasLoading || hasEmpty, isTrue);
    });

    testWidgets('Tab switching works without crash', (tester) async {
      setupScreen(tester);
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(wrap(const UserNetworkScreen(initialIndex: 0)));
      await tester.pump(const Duration(milliseconds: 500));

      // Tap the Followers tab
      await tester.tap(find.text('Followers'));
      await tester.pump(const Duration(milliseconds: 300));

      // Tap back to Following tab
      await tester.tap(find.text('Following'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('My Network'), findsOneWidget);
    });
  });
}
