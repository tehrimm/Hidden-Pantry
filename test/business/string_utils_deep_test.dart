import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/utils/string_utils.dart';

void main() {
  group('Real Business Tests: StringUtils Deep Cases', () {

    group('formatTotalTime', () {
      test('0 minutes returns 0m', () {
        expect(StringUtils.formatTotalTime(0), '0m');
      });

      test('Negative minutes returns 0m', () {
        expect(StringUtils.formatTotalTime(-100), '0m');
      });

      test('1 minute returns 1m', () {
        expect(StringUtils.formatTotalTime(1), '1m');
      });

      test('59 minutes returns 59m', () {
        expect(StringUtils.formatTotalTime(59), '59m');
      });

      test('60 minutes returns 1h (no minutes part)', () {
        expect(StringUtils.formatTotalTime(60), '1h');
      });

      test('61 minutes returns 1h 1m', () {
        expect(StringUtils.formatTotalTime(61), '1h 1m');
      });

      test('90 minutes returns 1h 30m', () {
        expect(StringUtils.formatTotalTime(90), '1h 30m');
      });

      test('120 minutes returns 2h (no minutes part)', () {
        expect(StringUtils.formatTotalTime(120), '2h');
      });

      test('121 minutes returns 2h 1m', () {
        expect(StringUtils.formatTotalTime(121), '2h 1m');
      });

      test('240 minutes returns 4h', () {
        expect(StringUtils.formatTotalTime(240), '4h');
      });

      test('1440 minutes (24h) returns 24h', () {
        expect(StringUtils.formatTotalTime(1440), '24h');
      });

      test('1441 minutes returns 24h 1m', () {
        expect(StringUtils.formatTotalTime(1441), '24h 1m');
      });

      test('65 minutes returns 1h 5m', () {
        expect(StringUtils.formatTotalTime(65), '1h 5m');
      });

      test('135 minutes returns 2h 15m', () {
        expect(StringUtils.formatTotalTime(135), '2h 15m');
      });
    });

    group('truncateWithMore', () {
      test('Empty string returns empty string', () {
        expect(StringUtils.truncateWithMore('', 10), '');
      });

      test('String shorter than limit returns unchanged', () {
        expect(StringUtils.truncateWithMore('Hello', 10), 'Hello');
      });

      test('String exactly at limit returns unchanged', () {
        expect(StringUtils.truncateWithMore('Hello', 5), 'Hello');
      });

      test('String one char over limit truncates and adds +more', () {
        expect(StringUtils.truncateWithMore('Hello!', 5), 'Hello+more');
      });

      test('Truncates long recipe title correctly', () {
        const title = 'Creamy Tuscan Garlic Chicken Pasta with Sun-dried Tomatoes';
        final result = StringUtils.truncateWithMore(title, 20);
        expect(result.endsWith('+more'), true);
        expect(result.length, lessThan(title.length));
      });

      test('Trimmed trailing whitespace before +more', () {
        // "Hello    " truncated at 8 → "Hello   ".trim() + "+more" = "Hello+more"
        expect(StringUtils.truncateWithMore('Hello    World', 8), 'Hello+more');
      });

      test('Limit of 0 appends +more to empty trim', () {
        expect(StringUtils.truncateWithMore('Hello', 0), '+more');
      });

      test('Single character within limit', () {
        expect(StringUtils.truncateWithMore('A', 1), 'A');
      });

      test('Single character over limit (limit=0)', () {
        expect(StringUtils.truncateWithMore('A', 0), '+more');
      });
    });
  });
}
