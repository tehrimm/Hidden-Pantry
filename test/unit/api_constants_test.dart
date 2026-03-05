import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/constants/api_constants.dart';

void main() {
  group('ApiConstants Tests', () {
    test('Constants should be defined', () {
      // Basic check to ensure the file is correctly imported and constants are accessible
      // Since it only has baseUrl currently
      expect(ApiConstants.baseUrl, isNotEmpty);
      expect(ApiConstants.baseUrl, contains('http'));
    });
  });
}
