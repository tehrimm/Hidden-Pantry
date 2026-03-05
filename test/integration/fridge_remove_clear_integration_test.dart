import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/state/state_management.dart';

void main() {
  group('Integration: Fridge remove and clear', () {
    test('Removes and clears inventory', () {
      final f = FridgeController();
      f.addMultipleItems(['onion', 'garlic', 'salt']);
      expect(f.inventory.length, 3);
      f.removeItem('garlic');
      expect(f.inventory.contains('garlic'), false);
      f.clearInventory();
      expect(f.inventory.isEmpty, true);
    });
  });
}

