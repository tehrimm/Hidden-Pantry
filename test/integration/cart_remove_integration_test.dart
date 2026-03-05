import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/state/state_management.dart';

void main() {
  group('Integration: Cart remove item', () {
    test('Decrements and removes at zero', () {
      final c = CartController();
      c.addItem('salt');
      c.addItem('salt');
      c.addItem('salt');
      c.removeItem('salt');
      expect(c.items['salt'], 2);
      c.removeItem('salt');
      c.removeItem('salt');
      expect(c.items.containsKey('salt'), false);
      expect(c.totalCount, 0);
    });
  });
}

