import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/utils/string_utils.dart';

class TimeChip extends StatelessWidget {
  final int minutes;
  const TimeChip({super.key, required this.minutes});
  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(StringUtils.formatTotalTime(minutes)));
  }
}

void main() {
  group('[Functional][Widget][TimeChip]', () {
    testWidgets('[Functional] shows formatted time text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: TimeChip(minutes: 75))),
        ),
      );
      expect(find.text('1h 15m'), findsOneWidget);
    });
  });
}

