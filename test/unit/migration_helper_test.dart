import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MigrationHelper Logic Tests', () {
    test('Name search transformation logic', () {
      final name = 'Chicken Pasta';
      final searchableName = name.toLowerCase();
      expect(searchableName, 'chicken pasta');
    });

    test('Handling null/empty fallback in migration', () {
      final String? name = null;
      final String? title = 'Fallback Title';
      final result = name ?? title ?? '';
      expect(result, 'Fallback Title');
    });
  });
}
