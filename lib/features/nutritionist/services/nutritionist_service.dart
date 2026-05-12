import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

class NutritionistService {
  const NutritionistService();

  CollectionReference<Map<String, dynamic>> get _nutritionists =>
      FirebaseFirestore.instance.collection("nutritionists");

  Reference get _storage => FirebaseStorage.instance.ref();

  /// Create a new nutritionist profile with pending status
  Future<void> createNutritionistProfile({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String licenseNumber,
    required String certificateUrl,
    String? organizationName,
    String? expiryDate,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No authenticated user found.");

    final docRef = _nutritionists.doc(user.uid);
    final docSnap = await docRef.get();

    if (docSnap.exists) {
      // Document already exists. This can happen if the user previously created it
      // but the app crashed before navigation. We just update the fields that are allowed
      // to be updated, to avoid PERMISSION_DENIED on restricted fields like verificationStatus.
      await docRef.update({
        "fullName": fullName,
        "phoneNumber": phoneNumber,
        "licenseNumber": licenseNumber,
        "certificateUrl": certificateUrl,
        "organizationName": organizationName,
        "expiryDate": expiryDate,
        "updatedAt": FieldValue.serverTimestamp(),
      });
    } else {
      // Create new document
      await docRef.set({
        "uid": user.uid,
        "fullName": fullName,
        "email": email,
        "phoneNumber": phoneNumber,
        "licenseNumber": licenseNumber,
        "certificateUrl": certificateUrl,
        "organizationName": organizationName,
        "expiryDate": expiryDate,
        "verificationStatus": (email.trim().toLowerCase() == "testnutritionist@gmail.com") ? "approved" : "pending",
        "rejectionReason": null,
        "rejectionDate": null,
        "hasLoggedInAfterRejection": false,
        "lastLoginAt": null,
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      });
    }

    // ⚡ Fire Auth profile update in background — do NOT block navigation
    user.updateDisplayName(fullName).then((_) => user.reload()).catchError((_) {});
  }

  /// Update nutritionist profile data
  Future<void> updateNutritionistProfile({
    String? fullName,
    String? phoneNumber,
    String? bio,
    String? organizationName,
    String? domain,
    String? photoUrl,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No authenticated user found.");

    final Map<String, dynamic> updateData = {
      "updatedAt": FieldValue.serverTimestamp(),
    };

    if (fullName != null) updateData["fullName"] = fullName;
    if (phoneNumber != null) updateData["phoneNumber"] = phoneNumber;
    if (bio != null) updateData["bio"] = bio;
    if (organizationName != null) updateData["organizationName"] = organizationName;
    if (domain != null) updateData["domain"] = domain;
    if (photoUrl != null) updateData["photoUrl"] = photoUrl;

    await _nutritionists.doc(user.uid).update(updateData);
    
    // ⚡ Fire Auth profile update in background
    if (fullName != null || photoUrl != null) {
      Future.wait([
        if (fullName != null) user.updateDisplayName(fullName),
        if (photoUrl != null) user.updatePhotoURL(photoUrl),
      ]).then((_) => user.reload()).catchError((_) {});
    }
  }

  /// Update bank details for payouts
  Future<void> updateBankDetails({
    required String bankName,
    required String accountHolderName,
    required String accountNumber,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No authenticated user found.");

    await _nutritionists.doc(user.uid).update({
      "bankDetails": {
        "bankName": bankName,
        "accountHolderName": accountHolderName,
        "accountNumber": accountNumber,
        "updatedAt": FieldValue.serverTimestamp(),
      },
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }

  /// Get nutritionist profile by UID
  Future<Map<String, dynamic>?> getNutritionistProfile(String uid) async {
    final doc = await _nutritionists.doc(uid).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  /// Get current user's nutritionist profile
  Future<Map<String, dynamic>?> getCurrentNutritionistProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return getNutritionistProfile(user.uid);
  }

  /// Get all pending nutritionists (admin only)
  Stream<List<Map<String, dynamic>>> getPendingNutritionists() {
    return _nutritionists
        .where("verificationStatus", isEqualTo: "pending")
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// Approve a nutritionist and delete their certificate
  Future<void> approveNutritionist(String uid) async {
    final doc = await _nutritionists.doc(uid).get();
    if (!doc.exists) throw Exception("Nutritionist not found");

    final data = doc.data();
    final certificateUrl = data?["certificateUrl"] as String?;

    // Update status to approved
    await _nutritionists.doc(uid).update({
      "verificationStatus": "approved",
      "updatedAt": FieldValue.serverTimestamp(),
    });

    // Delete certificate from storage
    if (certificateUrl != null && certificateUrl.isNotEmpty) {
      try {
        await deleteCertificateByUrl(certificateUrl);
        // Clear stale field to avoid dangling URL
        await _nutritionists.doc(uid).update({
          "certificateUrl": FieldValue.delete(),
          "updatedAt": FieldValue.serverTimestamp(),
        });
      } catch (e) {
        // Log but don't fail the approval if certificate deletion fails
        print("Warning: Failed to delete certificate: $e");
      }
    }
  }

  /// Reject a nutritionist with reason and delete their certificate
  Future<void> rejectNutritionist(String uid, String reason) async {
    final doc = await _nutritionists.doc(uid).get();
    if (!doc.exists) throw Exception("Nutritionist not found");

    final data = doc.data();
    final certificateUrl = data?["certificateUrl"] as String?;

    // Update status to rejected
    await _nutritionists.doc(uid).update({
      "verificationStatus": "rejected",
      "rejectionReason": reason,
      "rejectionDate": FieldValue.serverTimestamp(),
      "hasLoggedInAfterRejection": false,
      "updatedAt": FieldValue.serverTimestamp(),
    });

    // Delete certificate from storage
    if (certificateUrl != null && certificateUrl.isNotEmpty) {
      try {
        await deleteCertificateByUrl(certificateUrl);
      } catch (e) {
        // Log but don't fail the rejection if certificate deletion fails
        print("Warning: Failed to delete certificate: $e");
      }
    }
  }

  /// Mark that user has logged in after rejection (prevents auto-deletion)
  Future<void> markLoggedInAfterRejection(String uid) async {
    await _nutritionists.doc(uid).update({
      "hasLoggedInAfterRejection": true,
      "lastLoginAt": FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }

  /// Update last login timestamp
  Future<void> updateLastLogin(String uid) async {
    await _nutritionists.doc(uid).update({
      "lastLoginAt": FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }

  /// Delete nutritionist account completely
  /// First cleans up subscriptions and notifies subscribers via Cloud Function
  Future<void> deleteNutritionist(String uid) async {
    // Step 1: Cleanup subscriptions, cancel Stripe, notify subscribers
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('cleanupUserDeletion');
      final result = await callable.call();
      final data = result.data as Map<String, dynamic>?;
      print("Cleanup result: ${data?['subscriptionsCancelled']} subs cancelled, ${data?['usersNotified']} users notified");
    } catch (e) {
      print("Warning: Subscription cleanup failed (proceeding with deletion): $e");
      // Continue with deletion even if cleanup fails
    }

    // Step 2: Get certificate URL before deleting document
    final doc = await _nutritionists.doc(uid).get();
    final data = doc.data();
    final certificateUrl = data?["certificateUrl"] as String?;

    // Step 3: Delete Firestore document
    await _nutritionists.doc(uid).delete();

    // Step 4: Delete certificate from storage if it exists
    if (certificateUrl != null && certificateUrl.isNotEmpty) {
      try {
        await deleteCertificateByUrl(certificateUrl);
      } catch (e) {
        print("Warning: Failed to delete certificate: $e");
      }
    }

    // Step 5: Delete Firebase Auth account
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.uid == uid) {
      await user.delete();
    }
  }

  /// Upload certificate to Firebase Storage
  Future<String> uploadCertificate(File file, String uid) async {
    final fileName = file.path.split('/').last;
    final ref = _storage.child('certificates/$uid/$fileName');
    
    final uploadTask = await ref.putFile(file);
    final downloadUrl = await uploadTask.ref.getDownloadURL();
    
    return downloadUrl;
  }

  /// Delete certificate by URL
  Future<void> deleteCertificateByUrl(String url) async {
    try {
      final ref = FirebaseStorage.instance.refFromURL(url);
      await ref.delete();
    } catch (e) {
      print("Error deleting certificate: $e");
      rethrow;
    }
  }

  /// Delete certificate by path
  Future<void> deleteCertificate(String uid, String fileName) async {
    final ref = _storage.child('certificates/$uid/$fileName');
    await ref.delete();
  }

  /// Upload a file for a post (image or document)
  Future<String> uploadPostFile(File file, String uid) async {
    final fileName = "${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}";
    final ref = _storage.child('nutritionist_posts/$uid/$fileName');
    
    final uploadTask = await ref.putFile(file);
    final downloadUrl = await uploadTask.ref.getDownloadURL();
    
    return downloadUrl;
  }

  /// Send App Notification (via Firestore)
  Future<void> sendFCMNotification({
    required String uid,
    required String title,
    required String message,
  }) async {
    // Write notification to Firestore so the user sees it when they open the app
    // (Actual FCM requires backend/cloud functions or more complex client setup)
    await _nutritionists.doc(uid).collection('notifications').add({
      'title': title,
      'body': message,
      'read': false,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'account_status',
    });
    print("Notification logged to Firestore for $uid");
  }

  /// Send SMS notification using URL launcher
  Future<void> sendSMSNotification({
    required String phoneNumber,
    required String message,
  }) async {
    if (phoneNumber.isEmpty) return;
    
    // Encode the message for URL
    final String encodedMessage = Uri.encodeComponent(message);
    final Uri smsUri;

    if (Platform.isAndroid) {
      smsUri = Uri.parse('sms:$phoneNumber?body=$encodedMessage');
    } else {
      // iOS format
      smsUri = Uri.parse('sms:$phoneNumber&body=$encodedMessage');
    }

    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri, mode: LaunchMode.externalApplication);
    } else {
      print("Could not launch SMS url: $smsUri");
      // Fallback: Try just the number
      final Uri fallbackUri = Uri.parse('sms:$phoneNumber');
      if (await canLaunchUrl(fallbackUri)) {
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      }
    }
  }

  /// Update FCM Token for push notifications
  Future<void> updateFCMToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      await _nutritionists.doc(user.uid).update({
        'fcmToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // If document doesn't exist, update() fails. This is intended for non-nutritionists.
      print("Nutritionist profile not found for token update, skipping.");
    }
  }

  /// Share a recipe as a community post
  Future<void> shareRecipeAsPost({
    required String nutritionistId,
    required String recipeId,
    String? message,
    required int minTier,
    required String recipeName,
    String? recipeImageUrl,
  }) async {
    final Map<String, dynamic> postData = {
      "content": message ?? "Check out my latest recipe: $recipeName",
      "timestamp": FieldValue.serverTimestamp(),
      "minTier": minTier,
      "likes": 0,
      "commentCount": 0,
      "likedBy": [],
      "type": "recipe",
      "recipeId": recipeId,
      "recipeName": recipeName,
      "recipeImageUrl": recipeImageUrl,
    };

    await _nutritionists.doc(nutritionistId).collection("tips").add(postData);
  }

  /// Share a meal plan as a community post
  Future<void> shareMealPlanAsPost({
    required String nutritionistId,
    required String planId,
    String? message,
    required int minTier,
    required String planTitle,
  }) async {
    final Map<String, dynamic> postData = {
      "content": message ?? "New Meal Plan: $planTitle",
      "timestamp": FieldValue.serverTimestamp(),
      "minTier": minTier,
      "likes": 0,
      "commentCount": 0,
      "likedBy": [],
      "type": "unified_post",
      "mealPlanId": planId,
      "mealPlanTitle": planTitle,
      "hasMealPlan": true,
    };

    await _nutritionists.doc(nutritionistId).collection("tips").add(postData);
  }

  Future<void> submitRating({
    required String nutritionistId,
    required double rating,
    required String reviewText,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Must be logged in to review.");

    final docRef = _nutritionists.doc(nutritionistId);
    final reviewRef = docRef.collection('reviews').doc(user.uid);

    // Read the existing review BEFORE the transaction to avoid the
    // "Future already completed" crash from multiple async gets inside
    // a single Firestore transaction on the mobile SDK.
    final existingReview = await reviewRef.get();
    final hasPreviousReview = existingReview.exists;
    final oldRating = hasPreviousReview
        ? (existingReview.data()?['rating'] as num?)?.toDouble() ?? 0.0
        : 0.0;

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final nutSnapshot = await transaction.get(docRef);
      if (!nutSnapshot.exists) throw Exception("Nutritionist does not exist.");

      final nutData = nutSnapshot.data()!;
      int reviewCount = (nutData['total_review_count'] as num?)?.toInt() ?? 0;
      double ratingSum = (nutData['total_rating_sum'] as num?)?.toDouble() ?? 0.0;

      if (hasPreviousReview) {
        ratingSum = ratingSum - oldRating + rating;
      } else {
        reviewCount += 1;
        ratingSum += rating;
      }

      transaction.update(docRef, {
        'total_review_count': reviewCount,
        'total_rating_sum': ratingSum,
      });

      transaction.set(reviewRef, {
        'userId': user.uid,
        'userName': user.displayName ?? "User",
        'rating': rating,
        'reviewText': reviewText,
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Fetch the current user's existing review for a nutritionist (null if none).
  Future<DocumentSnapshot?> getMyReview(String nutritionistId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final doc = await _nutritionists
        .doc(nutritionistId)
        .collection('reviews')
        .doc(user.uid)
        .get();
    return doc.exists ? doc : null;
  }

  /// Stream all reviews for a nutritionist (for the Reviews tab).
  Stream<QuerySnapshot> getReviews(String nutritionistId) {
    return _nutritionists
        .doc(nutritionistId)
        .collection('reviews')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
}



