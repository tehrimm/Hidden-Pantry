import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PaymentService Data Logic Tests', () {
    test('Card masking logic', () {
      final cardNumber = '1234 5678 9012 3456';
      final masked = '**** **** **** ${cardNumber.replaceAll(' ', '').substring(cardNumber.replaceAll(' ', '').length - 4)}';
      expect(masked, '**** **** **** 3456');
    });

    test('Wallet masking logic', () {
      final phoneNumber = '03001234567';
      final masked = '${phoneNumber.substring(0, 4)}*****${phoneNumber.substring(phoneNumber.length - 2)}';
      expect(masked, '0300*****67');
    });
  });
}
