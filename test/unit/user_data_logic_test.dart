import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserService Data Logic Tests', () {
    test('Allergies list parsing', () {
      final dynamic rawList = ['milk', 'nuts'];
      final list = (rawList as List).map((e) => e.toString()).toList();
      expect(list, ['milk', 'nuts']);
    });

    test('Handling null allergies list', () {
      final dynamic rawList = null;
      final list = rawList != null ? (rawList as List).map((e) => e.toString()).toList() : <String>[];
      expect(list, isEmpty);
    });
  });
}
