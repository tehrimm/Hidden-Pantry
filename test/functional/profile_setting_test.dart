import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/user/screens/profile_setting.dart';
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

  group('Profile Setting Functional Tests', () {
    testWidgets('Renders header and text fields', (tester) async {
      setupScreen(tester);
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(wrap(const ProfileSettingScreen()));
      await tester.pump(const Duration(seconds: 1));

      // Screen title in fixed header
      expect(find.text('Your profile'), findsOneWidget);

      // 3 text fields: Full Name, Bio, Phone number (by hintText)
      expect(find.byType(TextField), findsNWidgets(3));

      // Toggle labels visible in viewport
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Voice-Controlled Cooking'), findsOneWidget);
    });

    testWidgets('Preferences card is present', (tester) async {
      setupScreen(tester);
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(wrap(const ProfileSettingScreen()));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Your Preferences'), findsOneWidget);
      expect(find.text('Change your allergies and diet preferences'), findsOneWidget);
    });

    testWidgets('Can toggle notification switch without crash', (tester) async {
      setupScreen(tester);
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(wrap(const ProfileSettingScreen()));
      await tester.pump(const Duration(seconds: 1));

      final notifFinder = find.text('Notifications');
      expect(notifFinder, findsOneWidget);

      await tester.tap(notifFinder);
      await tester.pump(const Duration(milliseconds: 300));

      // Should still show the toggle after tapping
      expect(find.text('Notifications'), findsOneWidget);
    });

    testWidgets('Can toggle voice switch without crash', (tester) async {
      setupScreen(tester);
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(wrap(const ProfileSettingScreen()));
      await tester.pump(const Duration(seconds: 1));

      final voiceFinder = find.text('Voice-Controlled Cooking');
      expect(voiceFinder, findsOneWidget);

      await tester.tap(voiceFinder);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Voice-Controlled Cooking'), findsOneWidget);
    });

    testWidgets('Save Changes button is present after scrolling', (tester) async {
      setupScreen(tester);
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(wrap(const ProfileSettingScreen()));
      await tester.pump(const Duration(seconds: 1));

      // Scroll to the bottom of the ListView to reveal the Save Changes button
      final listView = find.byType(ListView).first;
      await tester.drag(listView, const Offset(0, -800));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Save Changes'), findsOneWidget);
    });
  });
}
