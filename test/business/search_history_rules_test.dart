import 'package:flutter_test/flutter_test.dart';

List<String> updateHistory(List<String> history, String query, {int maxLen = 10}) {
  final q = query.trim();
  if (q.isEmpty) return history;
  final low = q.toLowerCase();
  final next = [q, ...history.where((e) => e.toLowerCase() != low)];
  if (next.length > maxLen) return next.sublist(0, maxLen);
  return next;
}

void main() {
  group('Business: Search history rules', () {
    test('Adds to front and dedups case-insensitively', () {
      final h0 = ['Pizza', 'pasta'];
      final h1 = updateHistory(h0, 'pAsTa');
      expect(h1.first, 'pAsTa');
      expect(h1.length, 2);
    });
    test('Ignores blanks and whitespace-only', () {
      final h0 = ['A'];
      final h1 = updateHistory(h0, '   ');
      expect(h1, h0);
    });
    test('Enforces max length', () {
      final h0 = List.generate(5, (i) => 'q$i'); // ['q0','q1','q2','q3','q4']
      final h1 = updateHistory(h0, 'new', maxLen: 5);
      expect(h1.first, 'new');
      expect(h1.length, 5);
      // Should drop the last ('q4')
      expect(h1.contains('q4'), false);
    });
  });
}
