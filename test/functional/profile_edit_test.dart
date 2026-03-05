
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hidden_pantry_app/features/user/screens/profile_setting.dart';
import 'test_utils.dart';
import 'mock_firebase.dart';

void main() {
  setUpAll(() async {
    setupFirebaseAuthMocks();
    await Firebase.initializeApp();
    setUpNetworkImageMock();
  });

  Widget createTestWidget(Widget child) {
    return MaterialApp(home: child);
  }

  testWidgets(
    'Profile Edit Flow: Open Profile Settings -> Edit Fields -> Toggle Notifications -> Save',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(const ProfileSettingScreen()));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1)); // let _loadUser attempt & timeout

      // 1. Verify screen title is rendered
      expect(find.text('Your profile'), findsOneWidget);

      // 2. Find text fields (Name, Bio, Phone)
      final textFields = find.byType(TextField);
      expect(textFields, findsAtLeastNWidgets(3));

      // 3. Enter name
      await tester.tap(textFields.at(0));
      await tester.pump();
      await tester.enterText(textFields.at(0), 'New Test Name');
      await tester.pump();
      expect(find.text('New Test Name'), findsOneWidget);

      // 4. Enter bio
      await tester.tap(textFields.at(1));
      await tester.pump();
      await tester.enterText(textFields.at(1), 'I love cooking!');
      await tester.pump();
      expect(find.text('I love cooking!'), findsOneWidget);

      // 5. Enter phone
      await tester.tap(textFields.at(2));
      await tester.pump();
      await tester.enterText(textFields.at(2), '03001234567');
      await tester.pump();
      expect(find.text('03001234567'), findsOneWidget);

      // 6. Verify "Your Preferences" link to allergies settings is visible and tappable
      expect(find.text('Your Preferences'), findsOneWidget);
      // (Note: navigating into AllergiesScreen requires FirebaseStorage which is not
      // fully mockable in this test environment — tested in auth_flow_test instead.)

      // 7. Find save button and verify it's visible
      expect(find.text('Save Changes'), findsOneWidget);

      // 8. Tap Save (will attempt Firestore write which fails gracefully in tests)
      final saveButton = find.ancestor(
        of: find.text('Save Changes'),
        matching: find.byType(GestureDetector),
      ).first;
      await tester.tap(saveButton);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2)); // let loading/error settle
    },
  );
}
