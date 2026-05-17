import 'dart:async';
import 'package:hidden_pantry_app/core/services/notification_service.dart';
import 'package:hidden_pantry_app/features/user/models/notification_model.dart';
import 'package:hidden_pantry_app/features/user/services/user_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';

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


  // Product IDs — format: subscriptionId:basePlanId (must match Google Play Console EXACTLY)
  // Platform Premium Monthly (Subscription: hidden_pantry_premium_monthly)
  static const String premiumMonthly = 'hidden_pantry_premium_monthly';
  // Platform Premium Annual (Subscription: hidden_pantry_premium_annual)
  static const String premiumAnnual = 'hidden_pantry_premium_annual';

  // Nutritionist Subscriptions
  static const String nutritionistSilverMonthly = 'nutritionist_silver';
  static const String nutritionistGoldMonthly = 'nutritionist_gold';
  static const String nutritionistPlatinumMonthly = 'nutritionist_platinum';

  static const Set<String> _productIds = {
    premiumMonthly, 
    premiumAnnual, 
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

  // Processed transaction cache to filter out native Google Play duplicate stream events
  final Set<String> _processedTransactions = {};

  // Local memory fallbacks to recover nutritionist information across purchase/restore events
  String? _purchasingNutritionistId;
  String? _purchasingPlanId;

  /// Set the currently purchasing or restoring nutritionist to prevent active_orphan state.
  void setPurchasingNutritionist(String? nutritionistId, String? planId) {
    _purchasingNutritionistId = nutritionistId;
    _purchasingPlanId = planId;
    debugPrint("IAP [DEBUG]: Set memory fallback nutritionistId=$nutritionistId, planId=$planId");
  }

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
      debugPrint("IAP [DEBUG]: isAvailable() returned $available");
      if (!available) {
        debugPrint("IAP [DEBUG]: Billing service is NOT available. This can happen if Play Store is missing or not logged in.");
      }

      debugPrint("IAP [DEBUG]: Querying products: $_productIds");
      final ProductDetailsResponse response = await _iap.queryProductDetails(_productIds);
      
      if (response.error != null) {
        debugPrint("IAP [ERROR]: Query Product Error: ${response.error!.message}");
        debugPrint("IAP [ERROR]: Details: ${response.error!.details}");
        // If service is not ready, retry once after 3 seconds
        if (response.error!.message.contains('not ready') || response.error!.message.contains('disconnected')) {
          await Future.delayed(const Duration(seconds: 3));
          return fetchProducts();
        }
      }

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint("IAP [WARNING]: Products NOT FOUND in store: ${response.notFoundIDs}");
        debugPrint("IAP [WARNING]: Ensure these EXACT IDs exist in Play Console and are Active.");
      }
      
      _products = response.productDetails;
      debugPrint("IAP [SUCCESS]: Loaded ${_products.length} products.");
      for (var p in _products) {
        debugPrint("IAP [DEBUG]: Product loaded: ${p.id} - ${p.title} - ${p.price}");
      }
      
      // If we still have no products and it's available, retry one more time after a longer delay
      if (_products.isEmpty && available) {
        Future.delayed(const Duration(seconds: 10), fetchProducts);
      }
    } catch (e) {
      debugPrint("IAP: Fatal error fetching products: $e");
    }
  }

  /// Start purchase flow with optional upgrade/downgrade support
  Future<void> buyProduct(ProductDetails product, {String? nutritionistId, String? planId, PurchaseDetails? oldPurchase, BuildContext? context}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint("IAP [ERROR]: Cannot buy product, user is null.");
      return;
    }

    debugPrint("IAP [DEBUG]: Attempting to buy product: ${product.id}");

    // Set memory fallback for instant stream listener verification
    if (nutritionistId != null) {
      _purchasingNutritionistId = nutritionistId;
      _purchasingPlanId = planId;
    }

    // If paying a nutritionist, record the target ID so we know who to credit later
    if (nutritionistId != null) {
      await FirebaseFirestore.instance.collection('pending_purchases').doc(user.uid).set({
        'nutritionistId': nutritionistId,
        'planId': planId,
        'productId': product.id,
        'timestamp': FieldValue.serverTimestamp(),
      });
      debugPrint("IAP [DEBUG]: Recorded pending purchase for nutritionist $nutritionistId");
    }

    PurchaseParam purchaseParam;
    
    if (Platform.isAndroid && oldPurchase != null && oldPurchase is GooglePlayPurchaseDetails && oldPurchase.productID != product.id) {
      debugPrint("IAP [DEBUG]: Upgrading/Downgrading from ${oldPurchase.productID} to ${product.id} via GooglePlayPurchaseParam");
      
      // Determine replacement mode based on upgrade vs downgrade tiers
      int getTier(String id) {
        if (id.contains('silver')) return 1;
        if (id.contains('gold')) return 2;
        if (id.contains('platinum')) return 3;
        if (id == IAPService.premiumMonthly) return 1;
        if (id == IAPService.premiumAnnual) return 2;
        return 0;
      }

      final oldTier = getTier(oldPurchase.productID);
      final newTier = getTier(product.id);
      
      ReplacementMode replacementMode;
      if (newTier < oldTier) {
        // Downgrade: defer until current billing cycle ends
        replacementMode = ReplacementMode.deferred;
        debugPrint("IAP [DEBUG]: Downgrade detected. Setting replacementMode to deferred.");
      } else {
        // Upgrade: charge the difference price immediately
        replacementMode = ReplacementMode.chargeProratedPrice;
        debugPrint("IAP [DEBUG]: Upgrade detected. Setting replacementMode to chargeProratedPrice.");
      }

      purchaseParam = GooglePlayPurchaseParam(
        productDetails: product,
        changeSubscriptionParam: ChangeSubscriptionParam(
          oldPurchaseDetails: oldPurchase,
          replacementMode: replacementMode,
        ),
      );
    } else {
      debugPrint("IAP [DEBUG]: Using standard PurchaseParam for purchase (no GooglePlay proration needed or available)");
      purchaseParam = PurchaseParam(
        productDetails: product,
      );
    }
    
    debugPrint("IAP [DEBUG]: Calling buyNonConsumable...");
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  /// Development-only bypass for testing premium flow
  Future<void> buyTesterProduct({required String productId, String? nutritionistId, String? planId, BuildContext? context, bool popOnSuccess = true}) async {
    final id = productId;
    
    // Set memory fallback for instant stream listener verification
    if (nutritionistId != null) {
      _purchasingNutritionistId = nutritionistId;
      _purchasingPlanId = planId;
    }

    // Simulate recording pending purchase for tester
    if (nutritionistId != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('pending_purchases').doc(user.uid).set({
          'nutritionistId': nutritionistId,
          'planId': planId,
          'productId': id,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    }

    // Determine premium messaging for testing
    String snackMsg = "Tester Access Granted: Premium Unlocked!";
    if (nutritionistId != null) {
      final oldPurchase = _activeNutritionistPurchases[nutritionistId];
      if (oldPurchase != null) {
        int getTier(String id) {
          if (id.contains('silver')) return 1;
          if (id.contains('gold')) return 2;
          if (id.contains('platinum')) return 3;
          return 0;
        }
        final oldTier = getTier(oldPurchase.productID);
        final newTier = getTier(id);
        
        if (newTier > oldTier) {
          snackMsg = "Tester: Subscription successfully upgraded to ${id.split('_').last.toUpperCase()}!";
        } else if (newTier < oldTier) {
          snackMsg = "Tester: Subscription successfully downgraded to ${id.split('_').last.toUpperCase()}!";
        } else {
          snackMsg = "Tester: Subscription refreshed!";
        }
      } else {
        snackMsg = "Tester: Subscribed successfully!";
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
        SnackBar(content: Text(snackMsg)),
      );
      if (popOnSuccess) {
        Navigator.pop(context);
      }
    }
  }

  /// Handle incoming purchase events
  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchase in purchaseDetailsList) {
      debugPrint("IAP [EVENT]: Purchase update received for ${purchase.productID} with status ${purchase.status}");
      
      if (purchase.status == PurchaseStatus.pending) {
        debugPrint("IAP [DEBUG]: Purchase is pending...");
      } else if (purchase.status == PurchaseStatus.error) {
        debugPrint("IAP [ERROR]: Purchase Error: ${purchase.error?.message} - ${purchase.error?.details}");
      } else if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
        debugPrint("IAP [SUCCESS]: Purchase successful: ${purchase.productID}");
        // Success! Update local tracking
        if (purchase.productID.contains('hidden_pantry_premium')) {
          _activePlatformPurchase = purchase;
        } else if (purchase.productID.contains('nutritionist')) {
           // We'd need more logic here to track which nutritionist, usually handled via pendings
        }
        
        // Success! Update Firestore
        await _verifyAndEnablePremium(purchase);
      }

      if (purchase.pendingCompletePurchase) {
        debugPrint("IAP [DEBUG]: Completing pending purchase...");
        await _iap.completePurchase(purchase);
      }
    }
  }

  /// Update user subscription status in Firestore
  Future<void> _verifyAndEnablePremium(PurchaseDetails purchase) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      if (purchase.purchaseID != null && _processedTransactions.contains(purchase.purchaseID)) {
        debugPrint("IAP [DEBUG]: Transaction ${purchase.purchaseID} already processed, ignoring duplicate event to prevent state inconsistencies.");
        return;
      }
      if (purchase.purchaseID != null) {
        _processedTransactions.add(purchase.purchaseID!);
      }

      final isNutritionistTier = purchase.productID.contains('nutritionist_');
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
        final pendingData = pendingDoc.data();
        
        // Recover nutritionistId and planId from pending document OR memory fallback
        String? nutritionistId = pendingData?['nutritionistId'] ?? _purchasingNutritionistId;
        String? planId = pendingData?['planId'] ?? _purchasingPlanId;
        
        // 🛡️ RECOVERY FOR SUBSEQUENT LAUNCHES / RENEWALS / RESTORES
        if (nutritionistId == null) {
          debugPrint("IAP [DEBUG]: nutritionistId is null in pending_purchases and memory fallback, searching for existing subscription to recover it...");
          final existingSubs = await FirebaseFirestore.instance
              .collection('subscriptions')
              .where('userId', isEqualTo: user.uid)
              .where('productId', isEqualTo: purchase.productID)
              .get();
          
          if (existingSubs.docs.isNotEmpty) {
            // Find a valid, non-null, non-empty nutritionistId from the subscription list
            for (var doc in existingSubs.docs) {
              final existingData = doc.data();
              final possibleNutId = existingData['nutritionistId'] as String?;
              if (possibleNutId != null && possibleNutId.isNotEmpty) {
                nutritionistId = possibleNutId;
                planId = existingData['planId'] as String?;
                debugPrint("IAP [DEBUG]: Recovered nutritionistId=$nutritionistId, planId=$planId from existing subscription");
                break;
              }
            }
          }
        }

        debugPrint("IAP [DEBUG]: nutritionistId=$nutritionistId, planId=$planId");
        
        if (nutritionistId != null) {
          // Track locally
          _activeNutritionistPurchases[nutritionistId] = purchase;

          // Find price for fee calculation
          double amount = 4000;
          if (purchase.productID.contains('gold')) amount = 6000;
          if (purchase.productID.contains('platinum')) amount = 8000;
          
          try {
            ProductDetails? p;
            for (var item in _products) {
              if (item.id == purchase.productID) {
                p = item;
                break;
              }
            }
            if (p != null) {
              amount = double.tryParse(p.price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? amount;
            }
          } catch (_) {}

          final googleFee = amount * 0.15;
          final platformFee = amount * 0.10;
          final nutritionistEarnings = amount - googleFee - platformFee;

          int tierLevel = 1;
          if (purchase.productID.contains('gold')) tierLevel = 2;
          if (purchase.productID.contains('platinum')) tierLevel = 3;

          // Check if subscription document already exists for this user and nutritionist
          final existingSubQuery = await FirebaseFirestore.instance
              .collection('subscriptions')
              .where('userId', isEqualTo: user.uid)
              .where('nutritionistId', isEqualTo: nutritionistId)
              .get();

          // Check if there is an active_orphan subscription we can heal
          final existingOrphanQuery = await FirebaseFirestore.instance
              .collection('subscriptions')
              .where('userId', isEqualTo: user.uid)
              .where('productId', isEqualTo: purchase.productID)
              .where('status', isEqualTo: 'active_orphan')
              .get();

          final batch = FirebaseFirestore.instance.batch();

          if (existingSubQuery.docs.isNotEmpty) {
            // Update the existing subscription document
            final existingDocRef = existingSubQuery.docs.first.reference;
            batch.update(existingDocRef, {
              'planId': planId ?? purchase.productID,
              'productId': purchase.productID,
              'tierLevel': tierLevel,
              'status': 'active',
              'startDate': FieldValue.serverTimestamp(),
              'expiryDate': Timestamp.fromDate(expiry),
              'billingSource': 'google_play',
              'error': FieldValue.delete(), // clear any previous errors
            });
            // Delete the orphaned document if we had one
            if (existingOrphanQuery.docs.isNotEmpty) {
              batch.delete(existingOrphanQuery.docs.first.reference);
            }
            debugPrint("IAP [DEBUG]: Updating existing subscription and cleaning up orphan in Firestore.");
          } else if (existingOrphanQuery.docs.isNotEmpty) {
            // Heal the existing orphan document
            final orphanDocRef = existingOrphanQuery.docs.first.reference;
            batch.update(orphanDocRef, {
              'nutritionistId': nutritionistId,
              'planId': planId ?? purchase.productID,
              'tierLevel': tierLevel,
              'status': 'active',
              'startDate': FieldValue.serverTimestamp(),
              'expiryDate': Timestamp.fromDate(expiry),
              'billingSource': 'google_play',
              'error': FieldValue.delete(), // clear error
            });
            debugPrint("IAP [DEBUG]: Healed existing orphan subscription in Firestore.");
          } else {
            // Create a new subscription document
            final newDocRef = FirebaseFirestore.instance.collection('subscriptions').doc();
            batch.set(newDocRef, {
              'userId': user.uid,
              'nutritionistId': nutritionistId,
              'planId': planId ?? purchase.productID,
              'productId': purchase.productID,
              'tierLevel': tierLevel,
              'status': 'active',
              'startDate': FieldValue.serverTimestamp(),
              'expiryDate': Timestamp.fromDate(expiry),
              'billingSource': 'google_play',
            });
            debugPrint("IAP [DEBUG]: Creating new subscription in Firestore.");
          }

          if (pendingDoc.exists) {
            batch.delete(pendingDoc.reference);
          }
          await batch.commit();
          debugPrint("IAP [SUCCESS]: Subscription recorded/updated in Firestore.");

          // Optional updates for the nutritionist (wrapped in try-catch to prevent client-side Firestore Security Rules from blocking checkout)
          try {
            final nutritionistBatch = FirebaseFirestore.instance.batch();
            
            nutritionistBatch.set(FirebaseFirestore.instance.collection('nutritionists').doc(nutritionistId), {
              'totalEarnings': FieldValue.increment(nutritionistEarnings),
            }, SetOptions(merge: true));

            nutritionistBatch.set(FirebaseFirestore.instance.collection('nutritionists').doc(nutritionistId).collection('earnings_history').doc(), {
              'amount': amount,
              'netEarnings': nutritionistEarnings,
              'platformFee': platformFee,
              'googleFee': googleFee,
              'userName': user.displayName ?? "Subscriber",
              'planTitle': purchase.productID.contains('silver') ? 'SILVER' : (purchase.productID.contains('gold') ? 'GOLD' : 'PLATINUM'),
              'timestamp': FieldValue.serverTimestamp(),
            });

            await nutritionistBatch.commit();
            debugPrint("IAP [SUCCESS]: Nutritionist earnings and history updated.");
          } catch (nutrErr) {
            debugPrint("IAP [WARNING]: Nutritionist earnings update failed (this is normal if Firestore Security Rules restrict client-side updates to public profiles): $nutrErr");
          }

          try {
            final String planName = purchase.productID.contains('silver') ? 'Silver' : (purchase.productID.contains('gold') ? 'Gold' : 'Platinum');
            NotificationService().sendNotification(
              recipientId: nutritionistId,
              title: "🎉 New Subscriber!",
              body: "${user.displayName ?? 'A user'} has joined your $planName plan.",
              type: NotificationType.subscription_alert,
              targetId: user.uid,
              recipientRole: 'nutritionist',
            );
          } catch (e) {
            debugPrint("IAP [ERROR]: Error notifying nutritionist: $e");
          }
        } else {
          // Create/update an orphan subscription only if we truly can't recover it, but NOT on duplicate stream updates
          final existingOrphanQuery = await FirebaseFirestore.instance
              .collection('subscriptions')
              .where('userId', isEqualTo: user.uid)
              .where('productId', isEqualTo: purchase.productID)
              .where('status', isEqualTo: 'active_orphan')
              .get();

          if (existingOrphanQuery.docs.isNotEmpty) {
            await existingOrphanQuery.docs.first.reference.update({
              'startDate': FieldValue.serverTimestamp(),
              'expiryDate': Timestamp.fromDate(expiry),
              'billingSource': 'google_play',
            });
            debugPrint("IAP [DEBUG]: Updated existing active_orphan subscription.");
          } else {
            // Check if user already has a valid active subscription for this product to prevent duplicate orphans
            final existingValidSubs = await FirebaseFirestore.instance
                .collection('subscriptions')
                .where('userId', isEqualTo: user.uid)
                .where('productId', isEqualTo: purchase.productID)
                .where('status', isEqualTo: 'active')
                .get();

            if (existingValidSubs.docs.isEmpty) {
              await FirebaseFirestore.instance.collection('subscriptions').add({
                'userId': user.uid,
                'productId': purchase.productID,
                'status': 'active_orphan',
                'startDate': FieldValue.serverTimestamp(),
                'expiryDate': Timestamp.fromDate(expiry),
                'billingSource': 'google_play',
                'error': 'nutritionist_id_missing',
              });
              debugPrint("IAP [DEBUG]: Created new active_orphan subscription.");
            } else {
              debugPrint("IAP [DEBUG]: Active subscription already exists, ignoring duplicate stream event to prevent orphan creation.");
            }
          }
        }
      } else if (isPlatformPremium) {
        // 🔵 USER BUYING PLATFORM PREMIUM
        final existingPlatformSubs = await FirebaseFirestore.instance
            .collection('subscriptions')
            .where('userId', isEqualTo: user.uid)
            .where('planId', isEqualTo: 'platform_premium')
            .get();

        if (existingPlatformSubs.docs.isNotEmpty) {
          // Update existing
          await existingPlatformSubs.docs.first.reference.update({
            'productId': purchase.productID,
            'purchaseId': purchase.purchaseID,
            'status': 'active',
            'startDate': FieldValue.serverTimestamp(),
            'expiryDate': Timestamp.fromDate(expiry),
            'interval': durationDays == 365 ? 'year' : (durationDays == 90 ? 'quarter' : 'month'),
            'billingSource': 'google_play',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          debugPrint("IAP [DEBUG]: Updated existing Platform Premium subscription in Firestore.");
        } else {
          // Create new
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
          debugPrint("IAP [DEBUG]: Created new Platform Premium subscription in Firestore.");
        }
        
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'isPremium': true,
          'subscriptionExpiry': Timestamp.fromDate(expiry),
        });
        debugPrint("IAP [SUCCESS]: Platform Premium recorded in Firestore.");
      }
    } catch (e, stack) {
      debugPrint("IAP [FATAL ERROR] during _verifyAndEnablePremium: $e");
      debugPrint(stack.toString());
    }
  }

  Future<void> restorePurchases() async {
    debugPrint("IAP [DEBUG]: Calling restorePurchases...");
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint("IAP [ERROR]: Failed to restore purchases: $e");
      rethrow;
    }
  }
}
