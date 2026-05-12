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
  static const String monthlyID = 'platform_premium_monthly';
  static const String annualID = 'platform_premium_annual';
  static const String nutritionistMembershipID = 'nutritionist_platform_membership';
  
  // Nutritionist Tiers (For users to subscribe to nutritionists)
  static const String nutritionistSilverMonthly = 'nutritionist_silver_monthly';
  static const String nutritionistSilverQuarterly = 'nutritionist_silver_quarterly';
  static const String nutritionistGoldMonthly = 'nutritionist_gold_monthly';
  static const String nutritionistGoldQuarterly = 'nutritionist_gold_quarterly';
  static const String nutritionistPlatinumMonthly = 'nutritionist_platinum_monthly';
  static const String nutritionistPlatinumQuarterly = 'nutritionist_platinum_quarterly';

  static const Set<String> _productIds = {
    monthlyID, 
    annualID, 
    nutritionistMembershipID,
    nutritionistSilverMonthly,
    nutritionistSilverQuarterly,
    nutritionistGoldMonthly,
    nutritionistGoldQuarterly,
    nutritionistPlatinumMonthly,
    nutritionistPlatinumQuarterly,
  };

  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  /// Initialize listeners
  void initialize() {
    if (_isTest) return;
    final purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription.cancel(),
      onError: (error) => debugPrint("IAP Error: $error"),
    );
  }

  /// Clean up
  void dispose() {
    _subscription.cancel();
  }

  /// Fetch products from store
  Future<void> fetchProducts() async {
    if (_isTest) {
      debugPrint("IAP: Skipping fetchProducts in test environment.");
      return;
    }
    try {
      final bool available = await _iap.isAvailable();
      if (!available) {
        debugPrint("IAP: Billing service is NOT available. Check if Play Store is set up.");
        return;
      }

      final ProductDetailsResponse response = await _iap.queryProductDetails(_productIds);
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint("IAP: Products not found in store: ${response.notFoundIDs}");
      }
      
      if (response.error != null) {
        debugPrint("IAP: Query Error: ${response.error!.message}");
      }

      _products = response.productDetails;
      debugPrint("IAP: Loaded ${_products.length} products successfully.");
    } catch (e) {
      debugPrint("IAP: Fatal error fetching products: $e");
    }
  }

  /// Start purchase flow
  Future<void> buyProduct(ProductDetails product, {String? nutritionistId, BuildContext? context}) async {
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

    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  /// Development-only bypass for testing premium flow
  Future<void> buyTesterProduct({String? productId, String? nutritionistId, BuildContext? context}) async {
    final id = productId ?? nutritionistMembershipID;
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

    final isNutritionistTier = purchase.productID.startsWith('nutritionist_');
    final isNutritionistMembership = purchase.productID == nutritionistMembershipID;
    
    int durationDays = 30; // Default Monthly
    if (purchase.productID == annualID || purchase.productID.contains('yearly') || purchase.productID.contains('annual')) {
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
        if (purchase.productID.contains('gold')) amount = 7000;
        if (purchase.productID.contains('platinum')) amount = 10000;
        
        // Adjust for quarterly
        if (purchase.productID.contains('quarterly')) {
          amount *= 2.75; // Roughly 3 months with a discount
        }
        
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
          'planTitle': purchase.productID.split('_').last.toUpperCase(),
          'timestamp': FieldValue.serverTimestamp(),
        });

        // 4. Clear pending
        batch.delete(pendingDoc.reference);

        await batch.commit();
      }
    } else if (isNutritionistMembership) {
      // 🟠 NUTRITIONIST JOINING PLATFORM
      await FirebaseFirestore.instance.collection('nutritionists').doc(user.uid).update({
        'isActive': true,
        'membershipExpiry': Timestamp.fromDate(expiry),
        'lastPaymentDate': FieldValue.serverTimestamp(),
      });
    } else {
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
        'productId': isAnnual ? annualID : monthlyID,
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
