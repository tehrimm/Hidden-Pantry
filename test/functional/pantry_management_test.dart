import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/screens/search/pantry_screen.dart';
import 'test_utils.dart';

class MockAssetBundle extends CachingAssetBundle {
  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (key == 'assets/data/ingredients_categorized.csv') {
      return '''ingredient,category
tomato,Vegetables
potato,Vegetables
chicken,Meat & Poultry
''';
    }
    if (key == 'AssetManifest.json' || key == 'FontManifest.json') {
      return '{}';
    }
    return super.loadString(key, cache: cache);
  }

  @override
  Future<ByteData> load(String key) async {
    // Return empty correctly-structured bytes for FontManifest/AssetManifest 
    // to prevent FormatException from StandardMessageCodec
    if (key == 'AssetManifest.json' || key == 'FontManifest.json' || key == 'AssetManifest.bin') {
      final ByteData? data = const StandardMessageCodec().encodeMessage({});
      if (data != null) return data;
    }
    return ByteData.view(Uint8List.fromList([
      137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82,
      0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0,
      0, 11, 73, 68, 65, 84, 8, 215, 99, 96, 0, 2, 0, 0, 5, 0, 1, 13,
      10, 45, 180, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130
    ]).buffer);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    setUpNetworkImageMock();
  });

  Widget createTestWidget(Widget child) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DefaultAssetBundle(
                      bundle: MockAssetBundle(),
                      child: child,
                    ),
                  ),
                );
              },
              child: const Text('Go'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('Pantry Management: Select Ingredients -> Done', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // 1. Open App, Tap Go to push Pantry Screen
    await tester.pumpWidget(createTestWidget(const PantryScreen()));
    await tester.tap(find.text('Go'));
    // Wait for route transition + CSV loading
    await tester.pumpAndSettle();

    // Verify ListView is now present
    expect(find.byType(ListView), findsWidgets);

    // Categories are capitalized from meta.title
    final vegetableFinder = find.text('Vegetables');
    await tester.dragUntilVisible(
      vegetableFinder,
      find.byType(ListView).first,
      const Offset(0, -500),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(vegetableFinder, findsWidgets);

    // Ingredients from CSV are lowercase
    final tomatoFinder = find.text('tomato');
    await tester.dragUntilVisible(
      tomatoFinder,
      find.byType(ListView).first,
      const Offset(0, -200),
    );
    await tester.pump(const Duration(seconds: 1));
    
    // Select an ingredient
    if (tester.any(tomatoFinder)) {
      await tester.tap(tomatoFinder.first);
      await tester.pump();
    }

    // 4. Tap Done
    await tester.tap(find.text('Done').last);
    await tester.pumpAndSettle();

    // After pop, the screen should be gone
    expect(find.byType(PantryScreen), findsNothing);
  });
}
