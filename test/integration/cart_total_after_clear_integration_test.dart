import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/state/state_management.dart';

void main() {
  group('Integration: Cart total after clear', () {
    test('Total resets to zero after clear', () {
      final c = CartController();
      c.addItem('a');
      c.addItem('b');
      expect(c.totalCount, 2);
      c.clearCart();
      expect(c.totalCount, 0);
      c.addItem('a');
      expect(c.totalCount, 1);
    });
  });
}

