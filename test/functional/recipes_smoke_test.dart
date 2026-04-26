import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/screens/my_recipes.dart';
import 'package:hidden_pantry_app/features/recipes/screens/saved_recipes.dart';
import 'package:hidden_pantry_app/features/recipes/screens/category_screen.dart';

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

  group('Recipe Feature Smoke Tests', () {
    testWidgets('MyRecipesScreen renders correctly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(MyRecipesScreen(auth: mockAuth)));
      await tester.pump(const Duration(seconds: 1)); // allow init and animations
      
      expect(find.textContaining('My Recipes'), findsWidgets);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('SavedRecipesScreen renders correctly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(SavedRecipesScreen(auth: mockAuth)));
      await tester.pump(const Duration(seconds: 1));
      
      expect(find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('Collection')), findsWidgets);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('CategoryScreen renders correctly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(CategoriesScreen(title: "Breakfast", tag: "Breakfast", apiService: MockRecipeApiService())));
      await tester.pump(const Duration(milliseconds: 100));
      
      expect(find.text("Breakfast"), findsWidgets);
    });
  });
}
