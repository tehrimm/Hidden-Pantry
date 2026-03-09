import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hidden_pantry_app/features/nutritionist/screens/discovery.dart';
import 'mock_firebase.dart';

void main() {
  setUpAll(() async {
    setupFirebaseAuthMocks();
    await Firebase.initializeApp();
  });

  Widget wrap(Widget child) => MaterialApp(home: child);

  testWidgets('Nutritionist Discovery: domain filter chips toggle selection', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(const NutritionistDiscoveryScreen(inShell: false)));
    await tester.pump();

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Sports Nutrition'), findsOneWidget);

    Text allBefore = tester.widget<Text>(find.text('All'));
    expect(allBefore.style?.fontWeight, FontWeight.bold);

    await tester.tap(find.text('Sports Nutrition'));
    await tester.pump();

    Text allAfter = tester.widget<Text>(find.text('All'));
    expect(allAfter.style?.fontWeight == FontWeight.bold, isFalse);

    Text sportsAfter = tester.widget<Text>(find.text('Sports Nutrition'));
    expect(sportsAfter.style?.fontWeight, FontWeight.bold);
  });
}
