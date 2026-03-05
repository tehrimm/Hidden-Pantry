import 'package:flutter_test/flutter_test.dart';

int clampBadge(int count, {int cap = 99}) {
  if (count < 0) return 0;
  return count > cap ? cap : count;
}

void main() {
  group('Business: Badge count capping', () {
    test('Negative values clamped to 0', () {
      expect(clampBadge(-5), 0);
    });
    test('Values under cap unchanged', () {
      expect(clampBadge(10), 10);
    });
    test('Values above cap clamped to cap', () {
      expect(clampBadge(120), 99);
    });
    test('Custom cap supported', () {
      expect(clampBadge(150, cap: 9), 9);
    });
  });
}

