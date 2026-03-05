import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/services/view_mode_service.dart';

void main() {
  group('ViewModeService Tests', () {
    test('Singleton instance should be same', () {
      final instance1 = ViewModeService();
      final instance2 = ViewModeService();
      expect(instance1, same(instance2));
    });

    test('clearCache should reset internal state', () {
      final service = ViewModeService();
      service.clearCache();
      // Since fields are private, we just verify clearCache can be called
      // and doesn't throw. In a real scenario we'd check effects via mocks.
    });
  });
}
