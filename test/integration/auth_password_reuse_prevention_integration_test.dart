import 'package:flutter_test/flutter_test.dart';

class PasswordHistoryPolicy {
  final int historySize;
  final List<String> _history = [];
  PasswordHistoryPolicy(this.historySize);
  bool canUse(String pwd) {
    return !_history.contains(pwd);
  }
  void record(String pwd) {
    _history.insert(0, pwd);
    if (_history.length > historySize) {
      _history.removeLast();
    }
  }
}

void main() {
  group('Integration: Password reuse prevention with history', () {
    test('Disallows recent reuse and allows when pushed out of window', () {
      final p = PasswordHistoryPolicy(3);
      p.record('p1');
      p.record('p2');
      p.record('p3');
      expect(p.canUse('p2'), false);
      expect(p.canUse('p4'), true);
      p.record('p4');
      expect(p.canUse('p1'), true);
    });
  });
}

