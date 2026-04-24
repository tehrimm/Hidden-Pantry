import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Centralized service to manage app-level subscriptions and feature gating.
class SubscriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  // Constants
  static const int maxFreeDownloads = 5;
  static const double premiumPricePKR = 250.0;

  /// Returns true if the current user has an active premium subscription.
  Future<bool> isPremiumUser() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      // Check for a platform subscription in the 'subscriptions' collection
      final snap = await _firestore
          .collection('subscriptions')
          .where('userId', isEqualTo: user.uid)
          .where('planId', isEqualTo: 'platform_premium')
          .where('status', isEqualTo: 'active')
          .get();

      if (snap.docs.isNotEmpty) {
        // Verify expiry date
        final data = snap.docs.first.data();
        final expiry = data['expiryDate'];
        if (expiry is Timestamp) {
          return expiry.toDate().isAfter(DateTime.now());
        }
      }
      
      // Fallback: Check user document for manual override/legacy flags
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      return userDoc.data()?['isPremium'] == true;
    } catch (e) {
      debugPrint("Error checking premium status: $e");
      return false;
    }
  }

  /// Returns true if the user's 7-day trial is currently active.
  Future<bool> isTrialActive() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final data = userDoc.data();
      if (data == null) return false;

      final createdAt = data['createdAt'] as Timestamp?;
      if (createdAt == null) return false;

      final trialExpiry = createdAt.toDate().add(const Duration(days: 7));
      return DateTime.now().isBefore(trialExpiry);
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

  /// Returns the number of remaining free downloads.
  Future<int> getRemainingDownloads() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final downloadedIds = List<String>.from(userDoc.data()?['downloadedRecipeIds'] ?? []);
      return (maxFreeDownloads - downloadedIds.length).clamp(0, maxFreeDownloads);
    } catch (e) {
      return 0;
    }
  }

  /// Tracks a recipe download. Returns true if allowed, false if blocked.
  Future<bool> trackDownload(String recipeId) async {
    if (await isPremiumUser() || await isTrialActive()) return true;

    final user = _auth.currentUser;
    if (user == null) return false;

    final userDocRef = _firestore.collection('users').doc(user.uid);
    final userDoc = await userDocRef.get();
    final downloadedIds = List<String>.from(userDoc.data()?['downloadedRecipeIds'] ?? []);

    if (downloadedIds.contains(recipeId)) return true; // Already counted

    if (downloadedIds.length >= maxFreeDownloads) {
      return false; // Limit reached
    }

    // Add to list
    await userDocRef.update({
      'downloadedRecipeIds': FieldValue.arrayUnion([recipeId]),
    });
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
    final user = _auth.currentUser;
    if (user == null) return false;

    // Nutritionists can always see their own recipes
    if (user.uid == nutritionistId) return true;

    try {
      final snap = await _firestore
          .collection('subscriptions')
          .where('userId', isEqualTo: user.uid)
          .where('nutritionistId', isEqualTo: nutritionistId)
          .where('status', isEqualTo: 'active')
          .get();

      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        final expiry = data['expiryDate'];
        if (expiry is Timestamp) {
          return expiry.toDate().isAfter(DateTime.now());
        }
      }
      return false;
    } catch (e) {
      debugPrint("Error checking nutritionist access: $e");
      return false;
    }
  }
}
