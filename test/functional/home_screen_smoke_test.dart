import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hidden_pantry_app/features/recipes/screens/home/home_screen.dart';
import 'package:hidden_pantry_app/features/recipes/screens/search/search.dart';
import 'package:hidden_pantry_app/features/user/screens/notifications_screen.dart';
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

  testWidgets('HomeScreen builds without overflow on small devices', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(HomeScreen(inShell: true, apiService: MockRecipeApiService(), auth: mockAuth)));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('HomeScreen shows voice search mic button', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(HomeScreen(inShell: true, apiService: MockRecipeApiService())));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byIcon(Icons.mic_rounded), findsWidgets);
  });

  testWidgets('HomeScreen voice search mic tap keeps screen stable', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(HomeScreen(inShell: true, apiService: MockRecipeApiService())));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byIcon(Icons.mic_rounded).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('HomeScreen search bar opens SearchScreen', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(HomeScreen(inShell: true, apiService: MockRecipeApiService())));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Search recipes, ingredients...'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byType(SearchScreen), findsOneWidget);
  });

  testWidgets('HomeScreen bell opens NotificationsScreen', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(HomeScreen(inShell: true, apiService: MockRecipeApiService())));
    await tester.pump(const Duration(milliseconds: 600));

    final bellIcon = find.byWidgetPredicate((w) {
      if (w is Image && w.image is AssetImage) {
        final img = w.image as AssetImage;
        return img.assetName.endsWith('notification.png');
      }
      return false;
    });
    expect(bellIcon, findsOneWidget);
    await tester.tap(bellIcon);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byType(NotificationsScreen), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });
}

