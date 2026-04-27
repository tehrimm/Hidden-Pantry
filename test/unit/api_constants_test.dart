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

    test('baseUrl should not have trailing slash', () {
      // It's a common standard that base URLs shouldn't end with / to avoid double slashes
      expect(ApiConstants.baseUrl.endsWith('/'), isFalse);
    });

    test('baseUrl should use a secure or standard protocol', () {
      expect(
        ApiConstants.baseUrl.startsWith('http://') || ApiConstants.baseUrl.startsWith('https://'), 
        isTrue,
        reason: 'Base URL must start with http:// or https://'
      );
    });
  });
}
