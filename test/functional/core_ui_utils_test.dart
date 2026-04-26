import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';
import 'package:hidden_pantry_app/core/utils/glass_dialog.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        home: Builder(builder: (context) {
          ResponsiveUtils.init(context);
          return Scaffold(body: child);
        }),
      );

  group('Core UI Utils Functional Tests', () {
    testWidgets('Toaster displays success message', (tester) async {
      await tester.pumpWidget(wrap(Builder(
        builder: (context) => ElevatedButton(
          onPressed: () {
            Toaster.show(context, "Success Notification");
          },
          child: const Text('Show Toast'),
        ),
      )));

      await tester.tap(find.text('Show Toast'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text("Success Notification"), findsOneWidget);
      
      // Clear Toaster timer (500ms in test mode)
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('Toaster displays error message', (tester) async {
      await tester.pumpWidget(wrap(Builder(
        builder: (context) => ElevatedButton(
          onPressed: () {
            Toaster.show(context, "Error Notification", isError: true);
          },
          child: const Text('Show Error'),
        ),
      )));

      await tester.tap(find.text('Show Error'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text("Error Notification"), findsOneWidget);
      
      // Clear Toaster timer
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('GlassDialog renders correctly', (tester) async {
      await tester.pumpWidget(wrap(Builder(
        builder: (context) => ElevatedButton(
          onPressed: () {
            GlassDialog.show(
              context: context,
              builder: (ctx) => const AlertDialog(title: Text("Glass Title")),
            );
          },
          child: const Text('Show Dialog'),
        ),
      )));

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text("Glass Title"), findsOneWidget);
    });
  });
}
