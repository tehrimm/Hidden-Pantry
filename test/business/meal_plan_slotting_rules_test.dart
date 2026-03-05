import 'package:flutter_test/flutter_test.dart';

class Slot {
  final int start; // minutes from 00:00
  final int end;   // minutes from 00:00, end > start
  const Slot(this.start, this.end);
}

bool overlaps(Slot a, Slot b) {
  return a.start < b.end && b.start < a.end;
}

List<Slot> addSlot(List<Slot> day, Slot s, {int maxPerDay = 6}) {
  // Capacity rule
  if (day.length >= maxPerDay) return day;
  // Overlap rule
  for (final existing in day) {
    if (overlaps(existing, s)) return day;
  }
  // Insert sorted by start
  final next = [...day, s]..sort((x, y) => x.start.compareTo(y.start));
  return next;
}

void main() {
  group('Business: Meal plan slotting rules', () {
    test('Rejects overlapping slots', () {
      final day = [Slot(8 * 60, 9 * 60)];
      final added = addSlot(day, Slot(8 * 60 + 30, 9 * 60 + 15));
      expect(added, day);
    });
    test('Allows touching boundaries (end == start)', () {
      final day = [Slot(8 * 60, 9 * 60)];
      final added = addSlot(day, Slot(9 * 60, 10 * 60));
      expect(added.length, 2);
    });
    test('Respects max per day', () {
      final base = List.generate(3, (i) => Slot(i * 60, i * 60 + 30));
      final added = addSlot(base, Slot(200, 240), maxPerDay: 3);
      expect(added, base);
    });
    test('Inserts sorted by start', () {
      final day = [Slot(600, 630), Slot(720, 750)];
      final added = addSlot(day, Slot(660, 690));
      expect(added.map((s) => s.start), [600, 660, 720]);
    });
  });
}

