import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/widgets/food_loader.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('FoodLoader Widget Tests', () {
    testWidgets('FoodLoader renders without error', (tester) async {
      await tester.pumpWidget(wrap(const FoodLoader()));
      expect(find.byType(FoodLoader), findsOneWidget);
      
      // Clear animation timer
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('FoodLoader respects custom size', (tester) async {
      // Wrap in Center + UnconstrainedBox to verify the widget's internal size
      await tester.pumpWidget(wrap(const Center(child: UnconstrainedBox(child: FoodLoader(size: 100)))));
      await tester.pump(const Duration(milliseconds: 100)); // allow layout
      
      final loaderFinder = find.byType(FoodLoader);
      final paintFinder = find.descendant(of: loaderFinder, matching: find.byType(CustomPaint));
      
      expect(tester.getSize(paintFinder), const Size(100, 100));
      
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
