import 'package:flutter_test/flutter_test.dart';

List<String> updateHistory(List<String> history, String query, {int maxLen = 10}) {
  final q = query.trim();
  if (q.isEmpty) return history;
  final low = q.toLowerCase();
  final next = [q, ...history.where((e) => e.toLowerCase() != low)];
  return next.length > maxLen ? next.sublist(0, maxLen) : next;
}

List<String> mergeSuggestions({
  required List<String> recent,
  required List<String> popular,
  required int limit,
}) {
  final seen = <String, String>{};
  void addAll(List<String> list) {
    for (final s in list) {
      final key = s.toLowerCase().trim();
      if (key.isEmpty) continue;
      if (!seen.containsKey(key)) seen[key] = s;
      if (seen.length >= limit) break;
    }
  }
  addAll(recent);
  if (seen.length < limit) addAll(popular);
  return seen.values.take(limit).toList();
}

void main() {
  group('Integration: Suggestions + history', () {
    test('History update feeds recent-first merge with popular', () {
      final h0 = ['Pizza', 'pasta'];
      final h1 = updateHistory(h0, 'sushi');
      final out = mergeSuggestions(recent: h1, popular: ['burger', 'pizza'], limit: 4);
      // recent first (sushi, then Pizza, pasta), then popular deduped
      expect(out, ['sushi', 'Pizza', 'pasta', 'burger']);
    });
  });
}

