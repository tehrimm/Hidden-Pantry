import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hidden_pantry_app/features/nutritionist/screens/nutritionist_dashboard.dart';
import 'package:hidden_pantry_app/core/widgets/nutritionist_bottom_nav.dart';
import 'test_utils.dart';
import 'mock_firebase.dart';

void main() {
  setUpAll(() async {
    setupFirebaseAuthMocks();
    await Firebase.initializeApp();
    setUpNetworkImageMock();
  });

  Widget wrap(Widget child) => MaterialApp(home: child);

  group('Nutritionist Dashboard tests', () {
    testWidgets('Dashboard renders bottom navigation', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(const NutritionistDashboard()));
      await tester.pump(const Duration(milliseconds: 100));
      
      // Use the correct custom bottom nav class
      expect(find.byType(NbBottomNav), findsOneWidget);
    });

    testWidgets('Dashboard shows main header', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(const NutritionistDashboard()));
      await tester.pump(const Duration(milliseconds: 100));
      
      // Check for the dashboard's greeting which is always present after loading
      expect(find.textContaining('Good'), findsWidgets);
      
      // Clear timers
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
