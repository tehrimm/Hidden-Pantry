import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/widgets/recipe_details_fab.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

  testWidgets('Start cooking FAB shows label when expanded manually', (tester) async {
    await tester.pumpWidget(
      wrap(
        AnimatedStartCookingFab(
          isExpandedManually: true,
          onTap: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Start Cooking'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward_ios_rounded), findsOneWidget);
  });

  testWidgets('Start cooking FAB triggers callback on tap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(
        AnimatedStartCookingFab(
          isExpandedManually: false,
          onTap: () => tapped = true,
        ),
      ),
    );

    await tester.tap(find.byType(AnimatedStartCookingFab));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 1200));

    expect(tapped, isTrue);
  });
}
