import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/user/services/stripe_service.dart';

void main() {
  group('StripeService Error Mapping Tests', () {
    test('Should map card_declined to friendly message', () {
      final error = 'Your card was declined. (code: card_declined)';
      final friendly = StripeService.friendlyError(error);
      expect(friendly, contains('card was declined'));
    });

    test('Should map insufficient_funds to friendly message', () {
      final friendly = StripeService.friendlyError('insufficient_funds');
      expect(friendly, contains('Insufficient funds'));
    });

    test('Should map expired_card to friendly message', () {
      final friendly = StripeService.friendlyError('expired_card');
      expect(friendly, contains('card has expired'));
    });

    test('Should handle unknown errors with fallback', () {
      final friendly = StripeService.friendlyError('something_weird');
      expect(friendly, contains('Payment could not be completed'));
    });
  });
}
