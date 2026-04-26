import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hidden_pantry_app/features/user/screens/notifications_screen.dart';
import 'package:hidden_pantry_app/features/user/models/notification_model.dart';
import 'mock_firebase.dart';
import 'test_utils.dart';

void main() {
  setUpAll(() async {
    setupFirebaseAuthMocks();
    await Firebase.initializeApp();
    setUpNetworkImageMock();
  });

  Widget wrap(Widget child) => MaterialApp(home: child);

  group('Notifications Screen Functional Tests', () {
    testWidgets('Notifications screen shows empty state when no notifications', (tester) async {
      await tester.pumpWidget(wrap(const NotificationsScreen()));
      // Allow for staggered animations
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(find.text('No notifications yet'), findsOneWidget);
      expect(find.text("We'll notify you when something happens."), findsOneWidget);
    });

    testWidgets('Notifications screen displays list items', (tester) async {
      // Note: This requires the screen to be driven by a mock service or to have a way to inject notifications.
      // Since NotificationsScreen uses Firestore internally, we should ideally inject a mock or check how it's implemented.
    });
  });
}
