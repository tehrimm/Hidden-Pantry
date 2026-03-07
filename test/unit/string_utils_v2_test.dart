import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/utils/string_utils.dart';

void main() {
  group('[Unit][StringUtils][formatTotalTime]', () {
    final cases = <int, String>{
      0: '0m',
      -5: '0m',
      5: '5m',
      60: '1h',
      75: '1h 15m',
      120: '2h',
      185: '3h 5m',
    };
    cases.forEach((mins, out) {
      test('[Unit][StringUtils][formatTotalTime] $mins -> $out', () {
        expect(StringUtils.formatTotalTime(mins), out);
      });
    });
  });

  group('[Unit][StringUtils][truncateWithMore]', () {
    test('[Unit][StringUtils][truncateWithMore] under limit untouched', () {
      expect(StringUtils.truncateWithMore('hello', 10), 'hello');
    });
    test('[Unit][StringUtils][truncateWithMore] exact limit untouched', () {
      expect(StringUtils.truncateWithMore('hello', 5), 'hello');
    });
    test('[Unit][StringUtils][truncateWithMore] over limit appends +more', () {
      expect(StringUtils.truncateWithMore('hello world', 5), 'hello+more');
    });
  });
}

