import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/state/state_management.dart';

void main() {
  group('Integration: Fridge add trim and dedupe', () {
    test('Trims and avoids duplicates', () {
      final f = FridgeController();
      f.addItem('  onion ');
      f.addItem('onion');
      f.addItem('garlic');
      expect(f.inventory.length, 2);
      expect(f.inventory.contains('onion'), true);
      expect(f.inventory.contains('garlic'), true);
    });
  });
}

