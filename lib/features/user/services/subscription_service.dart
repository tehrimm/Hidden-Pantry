import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Centralized service to manage app-level subscriptions and feature gating.
class SubscriptionService {
  final FirebaseFirestore? _firestore;
  final FirebaseAuth? _auth;
  final DateTime Function() _now;
  final Future<Map<String, dynamic>?> Function(String uid)? _loadUserDataOverride;
  final Future<List<Map<String, dynamic>>> Function(String uid)? _loadPlatformSubscriptionsOverride;
  final Future<List<Map<String, dynamic>>> Function(String uid, String nutritionistId)?
      _loadNutritionistSubscriptionsOverride;
  final Future<void> Function(String uid, String recipeId)? _appendDownloadedRecipeIdOverride;

  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal()
      : _firestore = FirebaseFirestore.instance,
        _auth = FirebaseAuth.instance,
        _now = DateTime.now,
        _loadUserDataOverride = null,
        _loadPlatformSubscriptionsOverride = null,
        _loadNutritionistSubscriptionsOverride = null,
        _appendDownloadedRecipeIdOverride = null;

  // Injectable constructor for deterministic unit tests.
  SubscriptionService.injectable({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    DateTime Function()? now,
    Future<Map<String, dynamic>?> Function(String uid)? loadUserData,
    Future<List<Map<String, dynamic>>> Function(String uid)? loadPlatformSubscriptions,
    Future<List<Map<String, dynamic>>> Function(String uid, String nutritionistId)?
        loadNutritionistSubscriptions,
    Future<void> Function(String uid, String recipeId)? appendDownloadedRecipeId,
  })  : _firestore = firestore,
        _auth = auth,
        _now = now ?? DateTime.now,
        _loadUserDataOverride = loadUserData,
        _loadPlatformSubscriptionsOverride = loadPlatformSubscriptions,
        _loadNutritionistSubscriptionsOverride = loadNutritionistSubscriptions,
        _appendDownloadedRecipeIdOverride = appendDownloadedRecipeId;

  // Constants
  static const int maxFreeDownloads = 5;
  static const double premiumPricePKR = 250.0;

  /// Returns true if the current user has an active premium subscription.
  Future<bool> isPremiumUser() async {
    final user = _auth?.currentUser;
    if (user == null) return false;

    try {
      final rows = _loadPlatformSubscriptionsOverride != null
          ? await _loadPlatformSubscriptionsOverride!(user.uid)
          : await _loadPlatformSubscriptions(user.uid);

      if (rows.isNotEmpty) {
        final expiry = rows.first['expiryDate'];
        if (expiry is Timestamp) {
          return expiry.toDate().isAfter(_now());
        }
        if (expiry is DateTime) {
          return expiry.isAfter(_now());
        }
      }

      final userData = _loadUserDataOverride != null
          ? await _loadUserDataOverride!(user.uid)
          : await _loadUserData(user.uid);
      return userData?['isPremium'] == true;
    } catch (e) {
      debugPrint("Error checking premium status: $e");
      return false;
    }
  }

  /// Returns true if the user's 7-day trial is currently active.
  Future<bool> isTrialActive() async {
    final user = _auth?.currentUser;
    if (user == null) return false;

    try {
      final data = _loadUserDataOverride != null
          ? await _loadUserDataOverride!(user.uid)
          : await _loadUserData(user.uid);
      if (data == null) return false;

      DateTime? trialExpiry;
      if (data['trialExpiresAt'] is Timestamp) {
        trialExpiry = (data['trialExpiresAt'] as Timestamp).toDate();
      } else if (data['trialExpiresAt'] is DateTime) {
        trialExpiry = data['trialExpiresAt'] as DateTime;
      } else if (data['trialExpiresAt'] is String) {
        trialExpiry = DateTime.tryParse(data['trialExpiresAt'] as String);
      }

      if (trialExpiry == null) {
        final createdAt = data['createdAt'];
        DateTime? createdDate;
        if (createdAt is Timestamp) {
          createdDate = createdAt.toDate();
        } else if (createdAt is DateTime) {
          createdDate = createdAt;
        } else if (createdAt is String) {
          createdDate = DateTime.tryParse(createdAt);
        }
        
        if (createdDate != null) {
          trialExpiry = createdDate.add(const Duration(days: 7));
        }
      }

      if (trialExpiry == null) return false;

      return _now().isBefore(trialExpiry);
    } catch (e) {
      return false;
    }
  }

  /// Combined check for access to any premium feature.
  Future<bool> canUsePremiumFeature() async {
    if (await isPremiumUser()) return true;
    if (await isTrialActive()) return true;
    return false;
  }

  /// Fetches all subscription-related info in a single object to minimize Firestore reads.
  Future<Map<String, dynamic>> getSubscriptionProfile() async {
    final user = _auth?.currentUser;
    if (user == null) {
      return {
        'isPremium': false,
        'isTrial': false,
        'remainingDownloads': 0,
        'usedDownloads': 0,
      };
    }

    final data = _loadUserDataOverride != null
        ? await _loadUserDataOverride!(user.uid)
        : await _loadUserData(user.uid);
    
    final isPremium = await isPremiumUser(); // This still checks platform subs
    final isTrial = await isTrialActive();
    
    // Support both old list and new counter
    int used = 0;
    if (data != null) {
      if (data['totalDownloadCount'] != null) {
        used = (data['totalDownloadCount'] as num).toInt();
      } else if (data['downloadedRecipeIds'] is List) {
        used = (data['downloadedRecipeIds'] as List).length;
      }
    }

    return {
      'isPremium': isPremium,
      'isTrial': isTrial,
      'remainingDownloads': (maxFreeDownloads - used).clamp(0, maxFreeDownloads),
      'usedDownloads': used,
    };
  }

  /// Returns the number of remaining free downloads.
  Future<int> getRemainingDownloads() async {
    final profile = await getSubscriptionProfile();
    return profile['remainingDownloads'];
  }

  /// Tracks a recipe download. Returns true if allowed, false if blocked.
  Future<bool> trackDownload(String recipeId) async {
    // 1. Premium users have unlimited downloads
    if (await isPremiumUser() || await isTrialActive()) return true;

    final user = _auth?.currentUser;
    if (user == null) return false;

    // 2. Fetch current usage
    final profile = await getSubscriptionProfile();
    if (profile['usedDownloads'] >= maxFreeDownloads) {
      return false; // Limit reached
    }

    // 3. Increment total count (allows same recipe to be counted multiple times if redownloaded)
    if (_appendDownloadedRecipeIdOverride != null) {
      await _appendDownloadedRecipeIdOverride!(user.uid, recipeId);
    } else {
      final firestore = _firestore ?? FirebaseFirestore.instance;
      await firestore.collection('users').doc(user.uid).update({
        'totalDownloadCount': FieldValue.increment(1),
        // We still keep the list for legacy support/UI but it's not the primary gate anymore
        'downloadedRecipeIds': FieldValue.arrayUnion([recipeId]),
      });
    }
    return true;
  }

  /// Centralized check for specific features.
  Future<bool> canUseFeature(String feature) async {
    switch (feature) {
      case 'voice_cooking':
      case 'image_recognition':
        return await canUsePremiumFeature();
      case 'recipe_download':
        // Downloads are allowed if premium, trial, or have remaining free slots
        if (await canUsePremiumFeature()) return true;
        return (await getRemainingDownloads()) > 0;
      default:
        return true;
    }
  }

  /// Checks if a user has an active subscription to a specific nutritionist.
  Future<bool> hasNutritionistAccess(String nutritionistId) async {
    final user = _auth?.currentUser;
    if (user == null) return false;

    // Nutritionists can always see their own recipes
    if (user.uid == nutritionistId) return true;

    try {
      final rows = _loadNutritionistSubscriptionsOverride != null
          ? await _loadNutritionistSubscriptionsOverride!(user.uid, nutritionistId)
          : await _loadNutritionistSubscriptions(user.uid, nutritionistId);

      if (rows.isNotEmpty) {
        final data = rows.first;
        final expiry = data['expiryDate'];
        if (expiry is Timestamp) {
          return expiry.toDate().isAfter(_now());
        }
        if (expiry is DateTime) {
          return expiry.isAfter(_now());
        }
      }
      return false;
    } catch (e) {
      debugPrint("Error checking nutritionist access: $e");
      return false;
    }
  }

  Future<Map<String, dynamic>?> _loadUserData(String uid) async {
    final firestore = _firestore ?? FirebaseFirestore.instance;
    final userDoc = await firestore.collection('users').doc(uid).get();
    return userDoc.data();
  }

  Future<List<Map<String, dynamic>>> _loadPlatformSubscriptions(String uid) async {
    final firestore = _firestore ?? FirebaseFirestore.instance;
    final snap = await firestore
        .collection('subscriptions')
        .where('userId', isEqualTo: uid)
        .where('planId', isEqualTo: 'platform_premium')
        .where('status', isEqualTo: 'active')
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }

  Future<List<Map<String, dynamic>>> _loadNutritionistSubscriptions(
    String uid,
    String nutritionistId,
  ) async {
    final firestore = _firestore ?? FirebaseFirestore.instance;
    final snap = await firestore
        .collection('subscriptions')
        .where('userId', isEqualTo: uid)
        .where('nutritionistId', isEqualTo: nutritionistId)
        .where('status', isEqualTo: 'active')
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }
}
