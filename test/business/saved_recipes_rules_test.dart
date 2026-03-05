import 'package:flutter_test/flutter_test.dart';

class SavedState {
  final List<String> ids;
  const SavedState(this.ids);
}

SavedState addSaved(SavedState s, String id) {
  if (s.ids.any((e) => e.toLowerCase() == id.toLowerCase())) return s;
  return SavedState([...s.ids, id]);
}

SavedState removeSaved(SavedState s, String id) {
  final next = s.ids.where((e) => e.toLowerCase() != id.toLowerCase()).toList();
  return SavedState(next);
}

void main() {
  group('Business: Saved recipes rules', () {
    test('Add saves uniquely (case-insensitive)', () {
      final s0 = SavedState(const []);
      final s1 = addSaved(s0, 'R1');
      final s2 = addSaved(s1, 'r1'); // duplicate by case
      expect(s1.ids, ['R1']);
      expect(s2.ids, ['R1']);
    });
    test('Remove works case-insensitively', () {
      final s0 = SavedState(const ['R1', 'r2']);
      final s1 = removeSaved(s0, 'R2');
      expect(s1.ids, ['R1']);
    });
    test('Order preserves insertion sequence', () {
      final s = addSaved(addSaved(SavedState(const []), 'a'), 'b');
      expect(s.ids, ['a', 'b']);
    });
  });
}

