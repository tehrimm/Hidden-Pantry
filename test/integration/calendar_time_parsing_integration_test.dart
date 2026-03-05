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
  group('Integration: Calendar time parsing', () {
    test('Parses 10:30 am to 10:30', () {
      final t = parseTime12h('10:30 am');
      expect(t.hour, 10);
      expect(t.minute, 30);
    });
    test('Parses 12 pm to 12:00', () {
      final t = parseTime12h('12 pm');
      expect(t.hour, 12);
      expect(t.minute, 0);
    });
    test('Parses 12:00 am to 00:00', () {
      final t = parseTime12h('12:00 am');
      expect(t.hour, 0);
      expect(t.minute, 0);
    });
    test('Parses 7:05 PM to 19:05', () {
      final t = parseTime12h('7:05 PM');
      expect(t.hour, 19);
      expect(t.minute, 5);
    });
  });
}

