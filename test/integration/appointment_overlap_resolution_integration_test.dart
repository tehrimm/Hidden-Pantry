import 'package:flutter_test/flutter_test.dart';

class Slot {
  final DateTime start;
  final DateTime end;
  Slot(this.start, this.end);
}

bool overlap(Slot a, Slot b) => a.start.isBefore(b.end) && b.start.isBefore(a.end);

Slot? findNextAvailable({
  required DateTime preferredStart,
  required Duration duration,
  required Map<DateTime, List<DateTime>> dailySlots,
  required List<Slot> existing,
}) {
  DateTime day = DateTime(preferredStart.year, preferredStart.month, preferredStart.day);
  for (int d = 0; d < 7; d++) {
    final slots = dailySlots[day] ?? const [];
    for (final t in slots) {
      final start = DateTime(day.year, day.month, day.day, t.hour, t.minute);
      if (start.isBefore(preferredStart)) continue;
      final candidate = Slot(start, start.add(duration));
      final conf = existing.any((e) => overlap(candidate, e));
      if (!conf) return candidate;
    }
    day = day.add(const Duration(days: 1));
  }
  return null;
}

void main() {
  group('Integration: Appointment overlap resolution', () {
    test('Selects the earliest non-conflicting slot from schedule', () {
      final day = DateTime(2026, 3, 10);
      final daily = {
        DateTime(day.year, day.month, day.day): [
          DateTime(0, 1, 1, 9, 0),
          DateTime(0, 1, 1, 10, 0),
          DateTime(0, 1, 1, 11, 0),
        ],
      };
      final existing = [
        Slot(DateTime(2026, 3, 10, 9, 0), DateTime(2026, 3, 10, 10, 0)),
      ];
      final preferred = DateTime(2026, 3, 10, 9, 0);
      final slot = findNextAvailable(
        preferredStart: preferred,
        duration: const Duration(hours: 1),
        dailySlots: daily,
        existing: existing,
      );
      expect(slot, isNotNull);
      expect(slot!.start.hour, 10);
      expect(slot.start.minute, 0);
    });
  });
}

