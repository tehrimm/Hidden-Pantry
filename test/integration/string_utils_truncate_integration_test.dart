import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/utils/string_utils.dart';

void main() {
  group('Integration: StringUtils truncateWithMore', () {
    test('Keeps short, truncates long', () {
      expect(StringUtils.truncateWithMore('abc', 5), 'abc');
      expect(StringUtils.truncateWithMore('abcdef', 3), 'abc+more');
    });
  });
}

