import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hidden_pantry_app/features/nutritionist/screens/discovery.dart';
import 'package:hidden_pantry_app/features/recipes/screens/search/search.dart';
import 'mock_firebase.dart';

void main() {
  setUpAll(() async {
    setupFirebaseAuthMocks();
    await Firebase.initializeApp();
  });

  Widget wrap(Widget child) => MaterialApp(home: child);

  testWidgets('Nutritionist Discovery: shows loading and bottom nav works', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(const NutritionistDiscoveryScreen(inShell: false)));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final searchIcon = find.byWidgetPredicate((w) {
      if (w is Image && w.image is AssetImage) {
        final img = w.image as AssetImage;
        return img.assetName.endsWith('search_inactive.png') || img.assetName.endsWith('Search_active.png');
      }
      return false;
    });
    expect(searchIcon, findsOneWidget);

    await tester.tap(searchIcon);
    await tester.pumpAndSettle();

    expect(find.byType(SearchScreen), findsOneWidget);
  });
}
