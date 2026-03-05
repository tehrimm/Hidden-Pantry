import 'package:flutter_test/flutter_test.dart';

class SearchResult {
  final String query;
  final int runCount;
  SearchResult(this.query, this.runCount);
}

class SearchManager {
  final Duration cooldown;
  DateTime? _lastRun;
  String? _lastQuery;
  int _runCount = 0;

  SearchManager(this.cooldown);

  SearchResult run(String query, DateTime now) {
    if (_lastRun != null &&
        now.difference(_lastRun!) < cooldown &&
        query.trim().toLowerCase() == (_lastQuery ?? '').toLowerCase()) {
      // serve from cache
      return SearchResult(query, _runCount);
    }
    _runCount += 1;
    _lastRun = now;
    _lastQuery = query;
    return SearchResult(query, _runCount);
    }
}

void main() {
  group('Integration: Search cooldown + caching', () {
    test('Same query within cooldown uses cached result; outside triggers new run', () {
      final mgr = SearchManager(const Duration(seconds: 30));
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      final r1 = mgr.run('pasta', t0);
      expect(r1.runCount, 1);
      final r2 = mgr.run('pasta', t0.add(const Duration(seconds: 10)));
      expect(r2.runCount, 1); // cached
      final r3 = mgr.run('pasta', t0.add(const Duration(seconds: 35)));
      expect(r3.runCount, 2); // new run
      final r4 = mgr.run('Pasta', t0.add(const Duration(seconds: 40)));
      expect(r4.runCount, 2); // case-insensitive cache still applies within cooldown
    });
  });
}

