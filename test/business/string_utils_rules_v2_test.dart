import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/utils/string_utils.dart';

void main() {
  group('[Business][Rules][StringUtils]', () {
    test('[Business] formatTotalTime basic rules', () {
      expect(StringUtils.formatTotalTime(0), '0m');
      expect(StringUtils.formatTotalTime(5), '5m');
      expect(StringUtils.formatTotalTime(60), '1h');
      expect(StringUtils.formatTotalTime(75), '1h 15m');
    });

    test('[Business] truncateWithMore rule behavior', () {
      expect(StringUtils.truncateWithMore('abcdef', 10), 'abcdef');
      expect(StringUtils.truncateWithMore('abcdef', 3), 'abc+more');
    });
  });
}

