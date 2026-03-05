import 'package:flutter_test/flutter_test.dart';

class SavedRecipe {
  final String id;
  final DateTime savedAt;
  final int minTier;
  SavedRecipe(this.id, this.savedAt, this.minTier);
}

List<SavedRecipe> buildSavedView({
  required List<SavedRecipe> items,
  required int userTier,
  int limit = 20,
}) {
  final Map<String, SavedRecipe> latest = {};
  for (final r in items) {
    if (userTier < r.minTier) continue;
    final existing = latest[r.id];
    if (existing == null || r.savedAt.isAfter(existing.savedAt)) {
      latest[r.id] = r;
    }
  }
  final out = latest.values.toList();
  out.sort((a, b) => b.savedAt.compareTo(a.savedAt));
  if (out.length > limit) return out.sublist(0, limit);
  return out;
}

void main() {
  group('Integration: Saved recipes sorting + gating', () {
    test('Dedups by id keeping latest, gates by tier, sorts desc, limits', () {
      final items = [
        SavedRecipe('r1', DateTime(2026, 1, 1, 12, 0), 0),
        SavedRecipe('r2', DateTime(2026, 1, 2, 12, 0), 2),
        SavedRecipe('r1', DateTime(2026, 1, 3, 12, 0), 0), // newer r1
        SavedRecipe('r3', DateTime(2026, 1, 2, 9, 0), 0),
      ];
      final out = buildSavedView(items: items, userTier: 1, limit: 10);
      // r2 gated by tier; r1 latest kept; order r1 (Jan 3) then r3 (Jan 2)
      expect(out.map((r) => r.id).toList(), ['r1', 'r3']);
    });
  });
}

