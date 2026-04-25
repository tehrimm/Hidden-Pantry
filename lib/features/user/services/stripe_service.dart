import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';

/// Wraps Stripe SDK + Cloud Function calls for payment operations.
class StripeService {
  const StripeService();

  // ─── Initialization (call once in main.dart) ──────────

  static void init({required String publishableKey}) {
    Stripe.publishableKey = publishableKey;
    // Stripe.merchantIdentifier = 'merchant.com.hiddenpantry'; // iOS Apple Pay
  }

  // ─── Card Tokenization ────────────────────────────────

  /// Tokenize card details into a Stripe PaymentMethod (PCI-compliant).
  /// Returns the PaymentMethod ID (pm_...).
  Future<String> createPaymentMethod({
    required String cardNumber,
    required String expMonth,
    required String expYear,
    required String cvc,
    required String cardHolderName,
  }) async {
    // Ensure 4-digit year
    int? year = int.tryParse(expYear);
    if (year != null && year < 100) {
      year += 2000;
    }

    // For manual card collection, we must use dangerouslyUpdateCardDetails
    // or tokenization. dangerouslyUpdateCardDetails is the internal state fix.
    await Stripe.instance.dangerouslyUpdateCardDetails(
      CardDetails(
        number: cardNumber,
        expirationMonth: int.tryParse(expMonth),
        expirationYear: year,
        cvc: cvc,
      ),
    );

    final pm = await Stripe.instance.createPaymentMethod(
      params: PaymentMethodParams.card(
        paymentMethodData: PaymentMethodData(
          billingDetails: BillingDetails(name: cardHolderName),
        ),
      ),
    );
    return pm.id;
  }

  // ─── Stripe Connect & Checkout ────────────────────────

  /// Onboard a nutritionist to Stripe Connect.
  /// Returns the account link URL.
  Future<String> onboardNutritionist() async {
    final callable = FirebaseFunctions.instance.httpsCallable('onboardNutritionist');
    final result = await callable.call();
    return result.data['url'] as String;
  }

  /// Create a Checkout session for a user to subscribe to a nutritionist.
  /// Returns the checkout URL.
  Future<String> createNutritionistCheckout({
    required String planId,
    required String planTitle,
    required double price,
    required String interval,
    required String nutritionistId,
    required String nutritionistName,
    String? existingSubscriptionId,
    int? tierLevel,
  }) async {
    final callable = FirebaseFunctions.instance.httpsCallable('createNutritionistCheckout');
    
    // Normalize numeric types and pass as strings to bypass Pigeon codec typing bugs
    // Pass the raw price; the Cloud Function will do the `* 100` conversion.
    final String priceStr = price.toString();
    final String tierStr = (tierLevel ?? 1).toString();
    
    final result = await callable.call({
      'planId': planId,
      'planTitle': planTitle,
      'price': priceStr,
      'interval': interval,
      'nutritionistId': nutritionistId,
      'nutritionistName': nutritionistName,
      'existingSubscriptionId': existingSubscriptionId ?? '',
      'tierLevel': tierStr,
    });
    return result.data['url'] as String;
  }



  /// Helper to open Stripe URLs.
  Future<void> launchStripeUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch payment URL');
    }
  }

  /// Calls Cloud Function to cancel a subscription at period end.
  Future<void> cancelSubscription({required String subscriptionDocId}) async {
    final callable = FirebaseFunctions.instance.httpsCallable('cancelSubscription');
    await callable.call({'subscriptionDocId': subscriptionDocId});
  }

  /// Calls Cloud Function to resume a cancelled subscription before it expires.
  Future<void> reactivateSubscription({required String subscriptionDocId}) async {
    final callable = FirebaseFunctions.instance.httpsCallable('resumeSubscription');
    await callable.call({'subscriptionDocId': subscriptionDocId});
  }

  // ─── Error Helpers ────────────────────────────────────

  /// Maps Stripe error codes to human-readable messages.
  static String friendlyError(dynamic error) {
    final msg = error.toString().toLowerCase();

    if (msg.contains('card_declined')) {
      return 'Your card was declined. Please check the card details or try a different card.';
    }
    if (msg.contains('insufficient_funds')) {
      return 'Insufficient funds. Please use a different card or add funds.';
    }
    if (msg.contains('expired_card')) {
      return 'Your card has expired. Please update your card details.';
    }
    if (msg.contains('incorrect_cvc')) {
      return 'The CVC code is incorrect. Please check and try again.';
    }
    if (msg.contains('processing_error')) {
      return 'A processing error occurred. Please try again in a moment.';
    }
    if (msg.contains('transfers') || msg.contains('capabilities')) {
      return 'The nutritionist has not fully set up their payments yet. Please inform them to complete their Stripe onboarding.';
    }
    if (msg.contains('network') || msg.contains('connection')) {
      return 'Network error. Please check your connection and try again.';
    }

    return 'Payment could not be completed. Please try again or use a different payment method. (Error: ${error.toString()})';
  }
}
