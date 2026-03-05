import 'package:flutter_test/flutter_test.dart';

class N {
  final String type;
  final String target;
  final DateTime t;
  N(this.type, this.target, this.t);
}

List<N> aggregate(List<N> xs, Duration window) {
  xs.sort((a, b) => a.t.compareTo(b.t));
  final out = <N>[];
  for (final n in xs) {
    if (out.isEmpty) {
      out.add(n);
      continue;
    }
    final last = out.last;
    final same = last.type == n.type && last.target == n.target;
    final within = n.t.difference(last.t) <= window;
    if (same && within) {
      out[out.length - 1] = N(last.type, last.target, n.t);
    } else {
      out.add(n);
    }
  }
  return out;
}

void main() {
  group('Integration: Notification window boundary grouping', () {
    test('Events outside window do not collapse', () {
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      final xs = [
        N('like', 'p1', t0),
        N('like', 'p1', t0.add(const Duration(minutes: 6))),
      ];
      final out = aggregate(xs, const Duration(minutes: 5));
      expect(out.length, 2);
    });
    test('Events at boundary or within collapse', () {
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      final xs = [
        N('like', 'p1', t0),
        N('like', 'p1', t0.add(const Duration(minutes: 5))),
      ];
      final out = aggregate(xs, const Duration(minutes: 5));
      expect(out.length, 1);
    });
  });
}

