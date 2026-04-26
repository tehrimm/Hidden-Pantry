import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/user/screens/my_subscriptions.dart';
import 'package:hidden_pantry_app/features/user/screens/my_favourites.dart';
import 'package:hidden_pantry_app/features/user/screens/notifications_screen.dart';
import 'package:hidden_pantry_app/features/user/screens/my_plans.dart';

import 'mock_firebase.dart';
import 'test_utils.dart';

void main() {
  setUpAll(() async {
    setupFirebaseAuthMocks();
    await Firebase.initializeApp();
    setUpNetworkImageMock();
  });

  Widget wrap(Widget child) => MaterialApp(home: child);

  group('User Feature Smoke Tests', () {
    testWidgets('MySubscriptionsScreen renders correctly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(const MySubscriptionsScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      
      expect(find.text('My Subscriptions'), findsWidgets);
      
      // Clear timers from _FadeSlideEntry
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('MyFavouritesScreen renders correctly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(const MyFavouritesScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      
      expect(find.text('My Favourites'), findsWidgets);
      
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('NotificationsScreen renders correctly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(const NotificationsScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      
      expect(find.text('Notifications'), findsWidgets);
      
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('MyPlansScreen renders correctly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(const MyPlansScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      
      expect(find.text('My Plans'), findsWidgets);
      
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
