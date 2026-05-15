import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Service to handle Google Play & Apple App Store Billing.
class IAPService {
  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  // Singleton
  static final IAPService _instance = IAPService._internal();
  factory IAPService() => _instance;
  IAPService._internal();

  /// Check if the current user is a designated tester account
  bool isTesterAccount() {
    final user = FirebaseAuth.instance.currentUser;
    return user?.email == 'hiddenpantry.support@gmail.com';
  }

  bool get _isTest => WidgetsBinding.instance.runtimeType.toString().contains('TestWidgetsFlutterBinding');


  // Product IDs (Must match Google Play Console)
  // Platform Premium (Subscription ID: hidden_pantry_premium)
  static const String premiumMonthly = 'hidden_pantry_premium:monthly-plan';
  static const String premiumAnnual = 'hidden_pantry_premium:annual-plan';
  static const String premiumDiscounted = 'hidden_pantry_premium:discounted-price';
  static const String premiumFreeTrial = 'hidden_pantry_premium:7-day-free-trial';
  
  // Nutritionist Subscriptions (Subscription ID: nutritionist_subscription)
  static const String nutritionistSilverMonthly = 'nutritionist_subscription:nutritionist-silver-monthly';
  static const String nutritionistGoldMonthly = 'nutritionist_subscription:nutritionist-gold-monthly';
  static const String nutritionistPlatinumMonthly = 'nutritionist_subscription:nutritionist-platinum-monthly';

  static const Set<String> _productIds = {
    premiumMonthly, 
    premiumAnnual, 
    premiumDiscounted,
    premiumFreeTrial,
    nutritionistSilverMonthly,
    nutritionistGoldMonthly,
    nutritionistPlatinumMonthly,
  };

  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  // Track active purchases for upgrades
  PurchaseDetails? _activePlatformPurchase;
  PurchaseDetails? get activePlatformPurchase => _activePlatformPurchase;
  
  final Map<String, PurchaseDetails> _activeNutritionistPurchases = {};
  PurchaseDetails? getActiveNutritionistPurchase(String nutritionistId) => _activeNutritionistPurchases[nutritionistId];

  /// Initialize listeners and fetch product data
  Future<void> initialize() async {
    if (_isTest) return;
    
    final purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription.cancel(),
      onError: (error) => debugPrint("IAP Error: $error"),
    );

    // Initial fetch
    await fetchProducts();
  }

  /// Clean up
  void dispose() {
    _subscription.cancel();
  }

  /// Fetch products from store
  Future<void> fetchProducts() async {
    if (_isTest) return;

    try {
      // Small delay to ensure billing service has time to connect
      await Future.delayed(const Duration(milliseconds: 500));
      
      final bool available = await _iap.isAvailable();
      if (!available) {
        debugPrint("IAP: Billing service is NOT available. Attempting to connect...");
        // On some devices, calling isAvailable() might not be enough, we just try to query
      }

      final ProductDetailsResponse response = await _iap.queryProductDetails(_productIds);
      
      if (response.error != null) {
        debugPrint("IAP: Query Error: ${response.error!.message}");
        // If service is not ready, retry once after 3 seconds
        if (response.error!.message.contains('not ready') || response.error!.message.contains('disconnected')) {
          await Future.delayed(const Duration(seconds: 3));
          return fetchProducts();
        }
      }

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint("IAP: Products not found in store: ${response.notFoundIDs}");
        // IMPORTANT: If products are missing, it might be due to propagation or ID mismatch.
        // We log it clearly so the user can see in debug logs.
      }
      
      _products = response.productDetails;
      debugPrint("IAP: Loaded ${_products.length} products successfully.");
      
      // If we still have no products and it's available, retry one more time after a longer delay
      if (_products.isEmpty && available) {
        Future.delayed(const Duration(seconds: 10), fetchProducts);
      }
    } catch (e) {
      debugPrint("IAP: Fatal error fetching products: $e");
    }
  }

  /// Start purchase flow with optional upgrade/downgrade support
  Future<void> buyProduct(ProductDetails product, {String? nutritionistId, PurchaseDetails? oldPurchase, BuildContext? context}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // If paying a nutritionist, record the target ID so we know who to credit later
    if (nutritionistId != null) {
      await FirebaseFirestore.instance.collection('pending_purchases').doc(user.uid).set({
        'nutritionistId': nutritionistId,
        'productId': product.id,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    final PurchaseParam purchaseParam = PurchaseParam(
      productDetails: product,
    );
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  /// Development-only bypass for testing premium flow
  Future<void> buyTesterProduct({String? productId, String? nutritionistId, BuildContext? context}) async {
    final id = productId ?? premiumMonthly;
    debugPrint("Tester account detected: Bypassing payment for $id");
    
    // Simulate recording pending purchase for tester
    if (nutritionistId != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('pending_purchases').doc(user.uid).set({
          'nutritionistId': nutritionistId,
          'productId': id,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    }

    await _verifyAndEnablePremium(PurchaseDetails(
      productID: id,
      purchaseID: 'tester_${DateTime.now().millisecondsSinceEpoch}',
      status: PurchaseStatus.purchased,
      transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
      verificationData: PurchaseVerificationData(localVerificationData: '', serverVerificationData: '', source: ''),
    ));
    
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tester Access Granted: Premium Unlocked!")),
      );
      Navigator.pop(context);
    }
  }

  /// Handle incoming purchase events
  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.pending) {
        // Show loading or wait
      } else if (purchase.status == PurchaseStatus.error) {
        debugPrint("Purchase Error: ${purchase.error}");
      } else if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
        // Success! Update local tracking
        if (purchase.productID.contains('hidden_pantry_premium')) {
          _activePlatformPurchase = purchase;
        } else if (purchase.productID.contains('nutritionist_subscription')) {
          // Note: We'd need the nutritionistId here, which isn't in PurchaseDetails.
          // Usually handled via pendings, but for upgrade we mostly care about platform premium.
        }
        
        // Success! Update Firestore
        await _verifyAndEnablePremium(purchase);
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  /// Update user subscription status in Firestore
  Future<void> _verifyAndEnablePremium(PurchaseDetails purchase) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final isNutritionistTier = purchase.productID.contains('nutritionist_subscription') || 
                               purchase.productID.contains('nutrionist_subscription');
    final isPlatformPremium = purchase.productID.contains('hidden_pantry_premium');
    
    int durationDays = 30; // Default Monthly
    if (purchase.productID.contains('annual') || purchase.productID.contains('yearly')) {
      durationDays = 365;
    } else if (purchase.productID.contains('quarterly')) {
      durationDays = 90;
    }
    
    final now = DateTime.now();
    final expiry = now.add(Duration(days: durationDays));

    if (isNutritionistTier) {
      // 🟢 USER SUBSCRIBING TO NUTRITIONIST
      final pendingDoc = await FirebaseFirestore.instance.collection('pending_purchases').doc(user.uid).get();
      final nutritionistId = pendingDoc.data()?['nutritionistId'];
      
      if (nutritionistId != null) {
        // Find price for fee calculation (fallback if product not loaded)
        double amount = 4000; // Silver Monthly default
        if (purchase.productID.contains('gold')) amount = 6000;
        if (purchase.productID.contains('platinum')) amount = 8000;
        
        try {
          final p = _products.firstWhere((element) => element.id == purchase.productID);
          // Parse price string (e.g. "Rs. 500") to double
          amount = double.tryParse(p.price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? amount;
        } catch (_) {}

        final googleFee = amount * 0.15;
        final platformFee = amount * 0.10;
        final nutritionistEarnings = amount - googleFee - platformFee;

        final batch = FirebaseFirestore.instance.batch();

        // 1. Add subscription for user
        batch.set(FirebaseFirestore.instance.collection('subscriptions').doc(), {
          'userId': user.uid,
          'nutritionistId': nutritionistId,
          'planId': purchase.productID,
          'productId': purchase.productID,
          'status': 'active',
          'startDate': FieldValue.serverTimestamp(),
          'expiryDate': Timestamp.fromDate(expiry),
          'billingSource': 'google_play',
        });

        // 2. Credit Nutritionist's Wallet
        batch.update(FirebaseFirestore.instance.collection('nutritionists').doc(nutritionistId), {
          'totalEarnings': FieldValue.increment(nutritionistEarnings),
        });

        // 3. Add to Earnings History
        batch.set(FirebaseFirestore.instance.collection('nutritionists').doc(nutritionistId).collection('earnings_history').doc(), {
          'amount': amount,
          'netEarnings': nutritionistEarnings,
          'platformFee': platformFee,
          'googleFee': googleFee,
          'userName': user.displayName ?? "Subscriber",
          'planTitle': purchase.productID.contains('silver') ? 'SILVER' : (purchase.productID.contains('gold') ? 'GOLD' : 'PLATINUM'),
          'timestamp': FieldValue.serverTimestamp(),
        });

        // 4. Clear pending
        batch.delete(pendingDoc.reference);

        await batch.commit();
      }
    } else if (isPlatformPremium) {
      // 🔵 USER BUYING PLATFORM PREMIUM
      await FirebaseFirestore.instance.collection('subscriptions').add({
        'userId': user.uid,
        'planId': 'platform_premium',
        'planTitle': 'Hidden Pantry Premium',
        'productId': purchase.productID,
        'purchaseId': purchase.purchaseID,
        'status': 'active',
        'startDate': FieldValue.serverTimestamp(),
        'expiryDate': Timestamp.fromDate(expiry),
        'interval': durationDays == 365 ? 'year' : (durationDays == 90 ? 'quarter' : 'month'),
        'billingSource': 'google_play',
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'isPremium': true,
        'subscriptionExpiry': Timestamp.fromDate(expiry),
      });
    }
  }

  /// 🧪 DEBUG ONLY: Simulate a successful purchase without involving the store.
  Future<void> test_simulatePurchaseSuccess(BuildContext context, bool isAnnual) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final expiry = isAnnual ? now.add(const Duration(days: 365)) : now.add(const Duration(days: 30));

    try {
      await FirebaseFirestore.instance.collection('subscriptions').add({
        'userId': user.uid,
        'planId': 'platform_premium',
        'planTitle': 'Hidden Pantry Premium',
        'productId': isAnnual ? premiumAnnual : premiumMonthly,
        'purchaseId': 'debug_${DateTime.now().millisecondsSinceEpoch}',
        'status': 'active',
        'startDate': FieldValue.serverTimestamp(),
        'expiryDate': Timestamp.fromDate(expiry),
        'interval': isAnnual ? 'year' : 'month',
        'billingSource': 'debug_bypass',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'isPremium': true,
        'subscriptionExpiry': Timestamp.fromDate(expiry),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Success! Premium Unlocked (Debug Mode)")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Debug Purchase Error: $e");
    }
  }
}
