import 'package:flutter_test/flutter_test.dart';

String paywallCtaLabel({required bool isAnnual}) {
  return isAnnual ? 'Subscribe Now' : 'Start 7-Day Free Trial';
}

bool showTrialBadge({required bool isAnnual}) => !isAnnual;

String paywallPriceLabel({
  required bool isAnnual,
  required Map<String, String> productPriceById,
}) {
  final key = isAnnual ? 'annual' : 'monthly';
  if (productPriceById.containsKey(key)) {
    return productPriceById[key]!;
  }
  return isAnnual ? 'Rs. 2850' : 'Rs. 250';
}

String paywallDisclaimer({required bool isAnnual}) {
  return isAnnual
      ? 'Charged annually. No trial included.'
      : 'No commitment. Cancel anytime before Day 7.';
}

void main() {
  group('Business: Premium paywall rules', () {
    test('Monthly plan CTA uses free-trial copy', () {
      expect(paywallCtaLabel(isAnnual: false), 'Start 7-Day Free Trial');
    });

    test('Annual plan CTA uses subscribe-now copy', () {
      expect(paywallCtaLabel(isAnnual: true), 'Subscribe Now');
    });

    test('Trial badge shown only for monthly selection', () {
      expect(showTrialBadge(isAnnual: false), true);
      expect(showTrialBadge(isAnnual: true), false);
    });

    test('Price label prefers loaded IAP price when available', () {
      expect(
        paywallPriceLabel(
          isAnnual: false,
          productPriceById: {'monthly': 'Rs. 300', 'annual': 'Rs. 3000'},
        ),
        'Rs. 300',
      );
      expect(
        paywallPriceLabel(
          isAnnual: true,
          productPriceById: {'monthly': 'Rs. 300', 'annual': 'Rs. 3000'},
        ),
        'Rs. 3000',
      );
    });

    test('Price label falls back to defaults when products are unavailable', () {
      expect(
        paywallPriceLabel(isAnnual: false, productPriceById: const {}),
        'Rs. 250',
      );
      expect(
        paywallPriceLabel(isAnnual: true, productPriceById: const {}),
        'Rs. 2850',
      );
    });

    test('Disclaimer text changes by billing cycle', () {
      expect(
        paywallDisclaimer(isAnnual: false),
        'No commitment. Cancel anytime before Day 7.',
      );
      expect(
        paywallDisclaimer(isAnnual: true),
        'Charged annually. No trial included.',
      );
    });
  });
}
