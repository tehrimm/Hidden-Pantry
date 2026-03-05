import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/state/state_management.dart';

void main() {
  group('Integration: Cart add item', () {
    test('Adds and increments count', () {
      final c = CartController();
      expect(c.totalCount, 0);
      c.addItem('salt');
      c.addItem('salt');
      c.addItem('sugar');
      expect(c.items['salt'], 2);
      expect(c.items['sugar'], 1);
      expect(c.totalCount, 3);
    });
  });
}

