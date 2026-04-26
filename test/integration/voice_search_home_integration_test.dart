import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/screens/home/home_screen.dart';
import 'package:hidden_pantry_app/features/recipes/screens/search/search.dart';
import 'package:hidden_pantry_app/features/user/screens/notifications_screen.dart';
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

  testWidgets('Integration: Home shows voice search mic affordance', (tester) async {
    await _setLargeViewport(tester);

    await tester.pumpWidget(wrap(const HomeScreen(inShell: true)));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byIcon(Icons.mic_rounded), findsWidgets);
  });

  testWidgets('Integration: Home voice mic tap keeps app stable', (tester) async {
    await _setLargeViewport(tester);

    await tester.pumpWidget(wrap(const HomeScreen(inShell: true)));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.byIcon(Icons.mic_rounded).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(
      find.byIcon(Icons.graphic_eq_rounded).evaluate().isNotEmpty ||
          find.byIcon(Icons.mic_rounded).evaluate().isNotEmpty,
      isTrue,
    );
  });

  testWidgets('Integration: Home search bar entry opens SearchScreen', (tester) async {
    await _setLargeViewport(tester);

    await tester.pumpWidget(wrap(const HomeScreen(inShell: true)));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Search recipes, ingredients...'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byType(SearchScreen), findsOneWidget);
  });

  testWidgets('Integration: Home notification bell opens notifications', (tester) async {
    await _setLargeViewport(tester);

    await tester.pumpWidget(wrap(const HomeScreen(inShell: true)));
    await tester.pump(const Duration(milliseconds: 600));

    final bellIcon = find.byWidgetPredicate((w) {
      if (w is Image && w.image is AssetImage) {
        final image = w.image as AssetImage;
        return image.assetName.endsWith('notification.png');
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

  testWidgets('Integration: Home small screen voice search still renders', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(const HomeScreen(inShell: true)));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsWidgets);
  });
}
