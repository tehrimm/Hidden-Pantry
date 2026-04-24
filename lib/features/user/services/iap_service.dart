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

  // Product IDs (Must match Google Play Console)
  static const String monthlyID = 'platform_premium_monthly';
  static const String annualID = 'platform_premium_annual';
  static const Set<String> _productIds = {monthlyID, annualID};

  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  /// Initialize listeners
  void initialize() {
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
    final bool available = await _iap.isAvailable();
    if (!available) return;

    final ProductDetailsResponse response = await _iap.queryProductDetails(_productIds);
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint("Products not found: ${response.notFoundIDs}");
    }
    _products = response.productDetails;
  }

  /// Start purchase flow
  Future<void> buyProduct(ProductDetails product) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    
    // For subscriptions, we use buyNonConsumable
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
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

    final isMonthly = purchase.productID == monthlyID;
    final now = DateTime.now();
    final expiry = isMonthly ? now.add(const Duration(days: 30)) : now.add(const Duration(days: 365));

    await FirebaseFirestore.instance.collection('subscriptions').add({
      'userId': user.uid,
      'planId': 'platform_premium',
      'planTitle': 'Hidden Pantry Premium',
      'productId': purchase.productID,
      'purchaseId': purchase.purchaseID,
      'status': 'active',
      'startDate': FieldValue.serverTimestamp(),
      'expiryDate': Timestamp.fromDate(expiry),
      'interval': isMonthly ? 'month' : 'year',
      'billingSource': 'google_play', // or 'app_store'
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    // Also update user doc for quick access
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'isPremium': true,
      'subscriptionExpiry': Timestamp.fromDate(expiry),
    });
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
