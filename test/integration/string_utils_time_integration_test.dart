import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/utils/string_utils.dart';

void main() {
  group('Integration: StringUtils format time', () {
    test('Formats minutes and hours', () {
      expect(StringUtils.formatTotalTime(0), "0m");
      expect(StringUtils.formatTotalTime(5), "5m");
      expect(StringUtils.formatTotalTime(60), "1h");
      expect(StringUtils.formatTotalTime(75), "1h 15m");
    });
  });
}

