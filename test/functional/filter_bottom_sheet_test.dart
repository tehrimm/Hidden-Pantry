import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/screens/search/filter_bottom_sheet.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: child);

  testWidgets('FilterBottomSheet applies selected time and tags', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    int? appliedMinutes;
    List<String>? appliedTags;

    await tester.pumpWidget(wrap(Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (_) => FilterBottomSheet(
                  initialMaxMinutes: null,
                  initialSelectedTags: const [],
                  onApply: (m, t) {
                    appliedMinutes = m;
                    appliedTags = t;
                  },
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    )));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Under 30 Minutes'));
    await tester.pump();

    // Ensure chips are visible in case of overflow
    await tester.ensureVisible(find.text('Vegan'));
    await tester.tap(find.text('Vegan'));
    await tester.pump();
    await tester.ensureVisible(find.text('Italian'));
    await tester.tap(find.text('Italian'));
    await tester.pump();

    await tester.ensureVisible(find.text('Apply Filters'));
    await tester.tap(find.text('Apply Filters'));
    await tester.pumpAndSettle();

    expect(appliedMinutes, 30);
    expect(appliedTags, isNotNull);
    expect(appliedTags!, contains('Vegan'));
    expect(appliedTags!, contains('Italian'));
  });
}
