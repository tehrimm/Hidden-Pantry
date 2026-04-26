import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/user/screens/premium_paywall_screen.dart';
import '../functional/mock_firebase.dart';
import '../functional/test_utils.dart';

void main() {
  setUpAll(() async {
    setupFirebaseAuthMocks();
    await Firebase.initializeApp();
    setUpNetworkImageMock();
  });

  Widget wrap(Widget child) => MaterialApp(home: child);

  Future<void> _setLargeViewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('Integration: Premium paywall renders major premium value props', (tester) async {
    await _setLargeViewport(tester);

    await tester.pumpWidget(wrap(const PremiumPaywallScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.textContaining('Hidden Pantry Premium'), findsOneWidget);
    expect(find.textContaining('Voice-Controlled Cooking'), findsOneWidget);
    expect(find.textContaining('Smart Ingredient Scan'), findsOneWidget);
    expect(find.textContaining('Unlimited Downloads'), findsOneWidget);
  });

  testWidgets('Integration: Premium paywall annual plan switches CTA copy', (tester) async {
    await _setLargeViewport(tester);

    await tester.pumpWidget(wrap(const PremiumPaywallScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    await tester.ensureVisible(find.text('Annual'));
    await tester.tap(find.text('Annual'));
    await tester.pump();

    expect(find.text('Subscribe Now'), findsOneWidget);
    expect(find.text('Start 7-Day Free Trial'), findsNothing);
  });

  testWidgets('Integration: Premium paywall monthly plan restores trial CTA', (tester) async {
    await _setLargeViewport(tester);

    await tester.pumpWidget(wrap(const PremiumPaywallScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    await tester.ensureVisible(find.text('Annual'));
    await tester.tap(find.text('Annual'));
    await tester.pump();
    await tester.tap(find.text('Monthly'));
    await tester.pump();

    expect(find.text('Start 7-Day Free Trial'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Integration: Premium privacy dialog opens with key safeguards', (tester) async {
    await _setLargeViewport(tester);

    await tester.pumpWidget(wrap(const PremiumPaywallScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    await tester.tap(find.byIcon(Icons.info_outline_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Your Privacy Matters'), findsOneWidget);
    expect(find.textContaining('No audio/image storage'), findsOneWidget);
    expect(find.textContaining('No external sharing'), findsOneWidget);
  });

  testWidgets('Integration: Premium paywall close button pops to previous route', (tester) async {
    await _setLargeViewport(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PremiumPaywallScreen()),
                  );
                },
                child: const Text('Open Paywall'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Paywall'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(PremiumPaywallScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Open Paywall'), findsOneWidget);
  });
}
