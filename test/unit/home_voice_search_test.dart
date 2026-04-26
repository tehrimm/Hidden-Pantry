import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/screens/home/home_screen.dart';

import '../functional/mock_firebase.dart';
import '../functional/test_utils.dart';

void main() {
  setUpAll(() async {
    setupFirebaseAuthMocks();
    await Firebase.initializeApp();
    setUpNetworkImageMock();
  });

  Widget wrap(Widget child) => MaterialApp(home: child);

  testWidgets('Home shows voice search mic button', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(const HomeScreen(inShell: true)));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
  });
}
