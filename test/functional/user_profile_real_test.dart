import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/user/screens/user_profile.dart';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'mock_firebase.dart';
import 'test_utils.dart';

void main() {
  late MockFirebaseAuth mockAuth;

  setUpAll(() async {
    setupFirebaseAuthMocks();
    await Firebase.initializeApp();
    setUpNetworkImageMock();

    mockAuth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(
        uid: 'test-uid',
        email: 'test@gmail.com',
        displayName: 'Test User',
      ),
    );
  });

  Widget wrap(Widget child) => MaterialApp(home: child);

  testWidgets('UserProfile Screen displays standard user settings actions', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(UserProfileScreen(
      auth: mockAuth,
      firestore: MockFirebaseFirestore(),
    )));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify main header (lowercase 'p')
    expect(find.text('My profile'), findsOneWidget);

    // Verify actual list tiles
    expect(find.text('Profile Setting'), findsOneWidget);
    expect(find.text('My Recipes'), findsOneWidget);
    expect(find.text('My Favourites'), findsOneWidget);
    expect(find.text('Meal Plans'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
    
    // Check for some icons
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    expect(find.byIcon(Icons.restaurant_menu_rounded), findsOneWidget);
    
    // Clear timers
    // Clear timers and allow profile load to timeout/complete
    await tester.pump(const Duration(seconds: 3));
  });
}
