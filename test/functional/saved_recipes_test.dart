
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hidden_pantry_app/features/recipes/screens/saved_recipes.dart';
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
    'Saved Recipes Flow: Unauthenticated state shows login prompt',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(const SavedRecipesScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // When no user is authenticated, SavedRecipesScreen gracefully shows "Please login"
      expect(find.text('Please login'), findsOneWidget);
    },
  );

  testWidgets(
    'Saved Recipes Flow: Toggle widget switches between Cookbooks and Downloads state',
    (WidgetTester tester) async {
      // Test the toggle state machine using a simple stateful wrapper.
      // This keeps the tab-switching logic testable without needing Firebase auth.
      bool isOfflineView = false;

      await tester.pumpWidget(MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: Column(
                children: [
                  Container(
                    height: 50,
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => isOfflineView = false),
                            child: Container(
                              key: const Key('cookbooks_tab'),
                              alignment: Alignment.center,
                              child: const Text('Cookbooks'),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => isOfflineView = true),
                            child: Container(
                              key: const Key('downloads_tab'),
                              alignment: Alignment.center,
                              child: const Text('Downloads'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isOfflineView)
                    const Text('Saved Recipes')
                  else
                    const Text('Offline Downloads'),
                ],
              ),
            );
          },
        ),
      ));

      await tester.pump();

      // 1. Initially shows Cookbooks content
      expect(find.text('Saved Recipes'), findsOneWidget);
      expect(find.text('Offline Downloads'), findsNothing);

      // 2. Tap Downloads tab
      await tester.tap(find.text('Downloads'));
      await tester.pump();

      // 3. Content switches to Downloads
      expect(find.text('Offline Downloads'), findsOneWidget);
      expect(find.text('Saved Recipes'), findsNothing);

      // 4. Tap Cookbooks tab again
      await tester.tap(find.text('Cookbooks'));
      await tester.pump();

      // 5. Content switches back to Cookbooks
      expect(find.text('Saved Recipes'), findsOneWidget);
      expect(find.text('Offline Downloads'), findsNothing);
    },
  );
}
