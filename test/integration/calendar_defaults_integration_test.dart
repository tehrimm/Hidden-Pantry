import 'package:flutter_test/flutter_test.dart';

class Event {
  final DateTime start;
  final DateTime end;
  final Duration reminder;
  Event(this.start, this.end, this.reminder);
}

Event createEvent(DateTime date, {Duration duration = const Duration(hours: 1), Duration reminder = const Duration(minutes: 30)}) {
  return Event(date, date.add(duration), reminder);
}

void main() {
  group('Integration: Calendar default duration and reminder', () {
    test('Defaults to 1 hour duration and 30 minute reminder', () {
      final start = DateTime(2026, 4, 1, 10, 0);
      final e = createEvent(start);
      expect(e.end.difference(e.start), const Duration(hours: 1));
      expect(e.reminder, const Duration(minutes: 30));
    });
    test('Custom duration overrides default', () {
      final start = DateTime(2026, 4, 1, 10, 0);
      final e = createEvent(start, duration: const Duration(minutes: 45));
      expect(e.end.difference(e.start), const Duration(minutes: 45));
    });
  });
}

