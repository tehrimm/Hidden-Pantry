import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/state/state_management.dart';

void main() {
  group('Integration: Cart clear', () {
    test('Clears all items', () {
      final c = CartController();
      c.addItem('salt');
      c.addItem('sugar');
      expect(c.totalCount, 2);
      c.clearCart();
      expect(c.totalCount, 0);
      expect(c.items.isEmpty, true);
    });
  });
}

