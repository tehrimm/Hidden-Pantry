import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hidden_pantry_app/features/nutritionist/screens/payout_management.dart';
import 'mock_firebase.dart';
import 'test_utils.dart';

void main() {
  setUpAll(() async {
    setupFirebaseAuthMocks();
    await Firebase.initializeApp();
    setUpNetworkImageMock();
  });

  Widget wrap(Widget child) => MaterialApp(home: child);

  group('Revenue & Payout Management Functional Tests', () {
    testWidgets('Payout Management displays earnings and Stripe status', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(PayoutManagementScreen(
        mockData: {
          'totalEarnings': 1000.0,
          'stripeAccountId': null,
        },
      )));
      await tester.pumpAndSettle();

      // Check title
      expect(find.text('Earnings & Fees'), findsOneWidget);

      // Check balance card elements
      expect(find.text('TOTAL EARNINGS'), findsOneWidget);
      expect(find.textContaining('Hidden Pantry deducts a 10% platform fee'), findsOneWidget);

      // Check Stripe section
      expect(find.text('Link Stripe Account'), findsWidgets);
      expect(find.text('Setup'), findsOneWidget);
    });

    testWidgets('Payout Management shows glassmorphic earnings history', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(PayoutManagementScreen(
        mockData: {
          'totalEarnings': 1500.0,
          'stripeAccountId': 'acct_123',
        },
      )));
      await tester.pumpAndSettle();

      expect(find.text('Earnings History'), findsOneWidget);
    });
  });
}
