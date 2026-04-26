import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/user/screens/premium_paywall_screen.dart';
import 'mock_firebase.dart';
import 'test_utils.dart';

void main() {
  setUpAll(() async {
    setupFirebaseAuthMocks();
    await Firebase.initializeApp();
    setUpNetworkImageMock();
  });

  Widget wrap(Widget child) => MaterialApp(home: child);

  testWidgets('Premium paywall renders core premium messaging and CTA', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(const PremiumPaywallScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.textContaining('Hidden Pantry Premium'), findsOneWidget);
    expect(find.textContaining('Voice-Controlled Cooking'), findsOneWidget);
    expect(find.textContaining('Smart Ingredient Scan'), findsOneWidget);
    expect(find.textContaining('Start 7-Day Free Trial'), findsOneWidget);
  });

  testWidgets('Premium paywall annual toggle switches CTA copy', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(const PremiumPaywallScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    await tester.ensureVisible(find.text('Annual'));
    await tester.tap(find.text('Annual'));
    await tester.pump();

    expect(find.text('Subscribe Now'), findsOneWidget);
    expect(find.text('Start 7-Day Free Trial'), findsNothing);
  });

  testWidgets('Premium paywall info button opens privacy dialog', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(const PremiumPaywallScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    await tester.tap(find.byIcon(Icons.info_outline_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Your Privacy Matters'), findsOneWidget);
    expect(find.textContaining('Voice Mode and Smart Scanning'), findsOneWidget);
  });
}
