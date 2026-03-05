import 'package:flutter_test/flutter_test.dart';

class TimeParts {
  final int hour;
  final int minute;
  const TimeParts(this.hour, this.minute);
}

TimeParts parseTime12h(String time) {
  final regex = RegExp(r'^\s*(\d{1,2})(?::(\d{1,2}))?\s*(am|pm)\s*$', caseSensitive: false);
  final m = regex.firstMatch(time);
  if (m == null) return const TimeParts(10, 0);
  var hour = int.tryParse(m.group(1) ?? '10') ?? 10;
  final minute = int.tryParse(m.group(2) ?? '0') ?? 0;
  final period = (m.group(3) ?? '').toLowerCase();
  if (period == 'pm' && hour < 12) hour += 12;
  if (period == 'am' && hour == 12) hour = 0;
  return TimeParts(hour, minute);
}

void main() {
  group('Integration: Invalid time parsing defaults', () {
    test('Invalid string falls back to 10:00', () {
      final t = parseTime12h('not a time');
      expect(t.hour, 10);
      expect(t.minute, 0);
    });
    test('Missing minutes defaults to :00', () {
      final t = parseTime12h('7 pm');
      expect(t.hour, 19);
      expect(t.minute, 0);
    });
  });
}

