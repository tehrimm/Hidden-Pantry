import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/user/screens/user_help_support.dart';
import 'test_utils.dart';

void main() {
  setUpAll(() async {
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

  group('User Help & Support Functional Tests', () {
    testWidgets('Renders header and contact card', (tester) async {
      setupScreen(tester);
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(wrap(const UserHelpSupportScreen()));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Help & Support'), findsOneWidget);
      expect(find.text('Need Help?'), findsOneWidget);
      expect(find.text('Contact Us'), findsOneWidget);
      expect(find.text('Frequently Asked Questions'), findsOneWidget);
    });

    testWidgets('First FAQ question is visible and tappable', (tester) async {
      setupScreen(tester);
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(wrap(const UserHelpSupportScreen()));
      await tester.pump(const Duration(seconds: 1));

      final firstFaqQuestion = find.text('How do I subscribe to a nutritionist?');
      expect(firstFaqQuestion, findsOneWidget);

      // Tap to expand
      await tester.tap(firstFaqQuestion);
      await tester.pump(const Duration(milliseconds: 300));

      // Tap again to collapse
      await tester.tap(firstFaqQuestion);
      await tester.pump(const Duration(milliseconds: 300));

      // Still visible after toggle
      expect(find.text('How do I subscribe to a nutritionist?'), findsOneWidget);
    });

    testWidgets('Second FAQ question is reachable by scrolling', (tester) async {
      setupScreen(tester);
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(wrap(const UserHelpSupportScreen()));
      await tester.pump(const Duration(seconds: 1));

      final secondFaqQuestion = find.text('Where can I find my active subscriptions?');
      await tester.dragUntilVisible(
        secondFaqQuestion,
        find.byType(ListView).first,
        const Offset(0, -300),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(secondFaqQuestion, findsOneWidget);

      await tester.tap(secondFaqQuestion);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('My Subscriptions'), findsWidgets);
    });

    testWidgets('Contact Us opens dialog', (tester) async {
      setupScreen(tester);
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(wrap(const UserHelpSupportScreen()));
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Contact Us'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Contact Support'), findsOneWidget);
      expect(find.text('support@hiddenpantry.app'), findsOneWidget);

      // Dismiss via tapping outside the dialog
      await tester.tapAt(const Offset(10, 10));
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('Quick Links section is reachable by scrolling', (tester) async {
      setupScreen(tester);
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(wrap(const UserHelpSupportScreen()));
      await tester.pump(const Duration(seconds: 1));

      final scrollable = find.byType(ListView).first;

      await tester.dragUntilVisible(
        find.text('Quick Links'),
        scrollable,
        const Offset(0, -300),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Quick Links'), findsOneWidget);

      await tester.dragUntilVisible(
        find.text('Terms of Service'),
        scrollable,
        const Offset(0, -300),
      );
      expect(find.text('Terms of Service'), findsOneWidget);

      await tester.dragUntilVisible(
        find.text('Privacy Policy'),
        scrollable,
        const Offset(0, -300),
      );
      expect(find.text('Privacy Policy'), findsOneWidget);
    });
  });
}
