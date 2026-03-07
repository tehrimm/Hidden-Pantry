import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class UserService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  UserService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection("users");

  Future<void> upsertCurrentUserProfile({
    required String fullName,
    required String phoneNumber,
    List<String> allergies = const [],
    String? bio,
    String? photoUrl,
    bool notificationsEnabled = true,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("No authenticated user found.");

    await _users.doc(user.uid).set({
      "uid": user.uid,
      "fullName": fullName,
      "email": user.email ?? "",
      "phone": phoneNumber,
      "bio": bio ?? "",
      "photoUrl": photoUrl,
      "notificationsEnabled": notificationsEnabled,
      "allergies": allergies,
      "role": "homecook",
      "provider": user.providerData.isNotEmpty
          ? user.providerData.first.providerId
          : "password",
      "updatedAt": FieldValue.serverTimestamp(),
      "createdAt": FieldValue.serverTimestamp(), 
    }, SetOptions(merge: true));

    // Also update Auth profile
    await user.updateDisplayName(fullName);
    if (photoUrl != null) await user.updatePhotoURL(photoUrl);
    await user.reload();
  }

  Future<void> updateProfile({
    String? fullName,
    String? bio,
    String? phone,
    String? photoUrl,
    bool? notificationsEnabled,
    DateTime? nameBioLastChangedAt,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("No authenticated user found.");

    final data = <String, dynamic>{
      "updatedAt": FieldValue.serverTimestamp(),
    };

    if (fullName != null) data["fullName"] = fullName;
    if (bio != null) data["bio"] = bio;
    if (phone != null) data["phone"] = phone;
    if (photoUrl != null) data["photoUrl"] = photoUrl;
    if (notificationsEnabled != null) data["notificationsEnabled"] = notificationsEnabled;
    if (nameBioLastChangedAt != null) {
      data["nameBioLastChangedAt"] = Timestamp.fromDate(nameBioLastChangedAt);
    }

    await _users.doc(user.uid).set(data, SetOptions(merge: true));

    if (fullName != null) await user.updateDisplayName(fullName);
    if (photoUrl != null) await user.updatePhotoURL(photoUrl);
    if (fullName != null || photoUrl != null) await user.reload();
  }

  Future<void> _ensureUserDoc(User user) async {
    final docRef = _users.doc(user.uid);
    final docSnap = await docRef.get();
    
    final existingData = docSnap.data();
    final existingName = existingData?['fullName'];
    final existingCreatedAt = existingData?['createdAt'];

    String finalName = "User";
    if (existingName != null && existingName != "User") {
      finalName = existingName;
    } else if (user.displayName != null && user.displayName!.isNotEmpty) {
      finalName = user.displayName!;
    }

    await docRef.set({
      "uid": user.uid,
      "email": user.email ?? "",
      "fullName": finalName,
      "role": existingData?['role'] ?? "homecook",
      "provider": user.providerData.isNotEmpty
          ? user.providerData.first.providerId
          : "password",
      "photoUrl": user.photoURL ?? existingData?['photoUrl'],
      "updatedAt": FieldValue.serverTimestamp(),
      if (existingCreatedAt == null) "createdAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Renaming to public if needed by login_user.dart
  Future<void> ensureUserDoc(User user) => _ensureUserDoc(user);

  Future<void> updateAllergies(List<String> allergies) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("No authenticated user found.");

    await _users.doc(user.uid).set({
      "allergies": allergies,
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<String>> getUserAllergies() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final doc = await _users.doc(user.uid).get();
    if (!doc.exists) return [];

    final data = doc.data();
    if (data == null) return [];

    final list = data['allergies'];
    if (list is List) {
      return list.map((e) => e.toString()).toList();
    }
    return [];
  }

  Future<void> updateFCMToken(String token) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    await _users.doc(user.uid).set({
      'fcmToken': token,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Permanently deletes all user data from Firestore, Storage, and Auth.
  Future<void> deleteUserAccount() async {
    // Step 0: Cleanup subscriptions (cancel Stripe, notify if nutritionist, etc.)
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('cleanupUserDeletion');
      await callable.call();
      print("[UserService] Account cleanup successful");
    } catch (e) {
      print("[UserService] Warning: Account cleanup failed (proceeding): $e");
    }

    final user = _auth.currentUser;
    if (user == null) throw Exception("No authenticated user found.");
    final uid = user.uid;

    final firestore = _firestore;
    final storage = _storage;

    // 1. Delete user-created recipes and their images
    final recipesSnap = await firestore
        .collection('recipes')
        .where('author_id', isEqualTo: uid)
        .get();

    for (var doc in recipesSnap.docs) {
      final recipeId = doc.id;
      // Delete Firestore doc
      await doc.reference.delete();
      
      // Delete images from Storage
      try {
        final storageRef = storage.ref().child('recipe_photos/$recipeId');
        final listResult = await storageRef.listAll();
        for (var item in listResult.items) {
          await item.delete();
        }
        final stepsRef = storageRef.child('steps');
        final stepsList = await stepsRef.listAll();
        for (var item in stepsList.items) {
          await item.delete();
        }
      } catch (e) {
        print("[UserService] Error deleting recipe images: $e");
      }
    }

    // 2. Delete user reviews and replies
    final reviewsSnap = await firestore
        .collection('reviews')
        .where('userId', isEqualTo: uid)
        .get();

    for (var doc in reviewsSnap.docs) {
      final data = doc.data();
      final imageUrl = data['imageUrl'];
      try {
        if (imageUrl is String && imageUrl.trim().isNotEmpty) {
          final ref = FirebaseStorage.instance.refFromURL(imageUrl);
          await ref.delete();
        }
      } catch (e) {
        print("[UserService] Error deleting review image: $e");
      }
      final repliesSnap = await doc.reference.collection('replies').get();
      for (var reply in repliesSnap.docs) {
        await reply.reference.delete();
      }
      await doc.reference.delete();
    }

    // NEW: Remove likes from others' tips
    try {
      final likedTipsSnap = await firestore.collectionGroup('tips').where('likedBy', arrayContains: uid).get();
      for (var doc in likedTipsSnap.docs) {
        await doc.reference.update({
          'likedBy': FieldValue.arrayRemove([uid]),
          'likes': FieldValue.increment(-1),
        });
      }
    } catch (e) {
      print("[UserService] Error cleaning up likes: $e");
    }

    // NEW: Delete comments made by user
    try {
      final commentsSnap = await firestore.collectionGroup('comments').where('userId', isEqualTo: uid).get();
      for (var doc in commentsSnap.docs) {
        final tipRef = doc.reference.parent.parent;
        if (tipRef != null) {
          await tipRef.update({'commentCount': FieldValue.increment(-1)}).catchError((_) {});
        }
        await doc.reference.delete();
      }
    } catch (e) {
      print("[UserService] Error cleaning up comments: $e");
    }

    // 3. Delete nutritionist profile and subcollections (if exists)
    final nutrRef = firestore.collection('nutritionists').doc(uid);
    final nutrDoc = await nutrRef.get();
    if (nutrDoc.exists) {
      final nutrData = nutrDoc.data();
      final certUrl = nutrData?['certificateUrl'];
      if (certUrl is String && certUrl.trim().isNotEmpty) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(certUrl);
          await ref.delete();
        } catch (e) {
          print("[UserService] Error deleting certificate: $e");
        }
      }
      final subColls = ['notifications', 'subscription_plans', 'tips', 'meal_plans'];
      for (var coll in subColls) {
        final snap = await nutrRef.collection(coll).get();
        for (var doc in snap.docs) {
          try {
            final data = doc.data() as Map<String, dynamic>?;
            final imageUrl = data?['imageUrl'];
            final docUrl = data?['docUrl'];
            if (imageUrl is String && imageUrl.trim().isNotEmpty) {
              final ref = FirebaseStorage.instance.refFromURL(imageUrl);
              await ref.delete();
            }
            if (docUrl is String && docUrl.trim().isNotEmpty) {
              final ref = FirebaseStorage.instance.refFromURL(docUrl);
              await ref.delete();
            }
          } catch (e) {
            print("[UserService] Error deleting nutritionist attachments: $e");
          }
          await doc.reference.delete();
        }
      }
      await nutrRef.delete();
    }

    // 4. Delete user profile and its subcollections
    final userRef = _users.doc(uid);

    // NEW: Cleanup social network counts and docs on targets
    try {
      final followingSnap = await userRef.collection('following').get();
      for (var doc in followingSnap.docs) {
        final authorId = doc.id;
        await firestore.collection('users').doc(authorId).update({'followerCount': FieldValue.increment(-1)}).catchError((_) {});
        await firestore.collection('users').doc(authorId).collection('followers').doc(uid).delete();
      }

      final followersSnap = await userRef.collection('followers').get();
      for (var doc in followersSnap.docs) {
        final followerId = doc.id;
        await firestore.collection('users').doc(followerId).update({'followingCount': FieldValue.increment(-1)}).catchError((_) {});
        await firestore.collection('users').doc(followerId).collection('following').doc(uid).delete();
      }
    } catch (e) {
      print("[UserService] Error cleaning up social network: $e");
    }

    // Delete internal subcollections
    final userSubColls = ['payment_methods', 'cookbooks', 'likes', 'following', 'followers', 'saved_meal_plans', 'notifications'];
    for (var coll in userSubColls) {
      final snap = await userRef.collection(coll).get();
      for (var doc in snap.docs) {
        await doc.reference.delete();
      }
    }

    // NEW: Delete top-level subscriptions
    try {
      final subsSnap = await firestore.collection('subscriptions').where('userId', isEqualTo: uid).get();
      for (var doc in subsSnap.docs) await doc.reference.delete();
    } catch (e) {
      print("[UserService] Error deleting subscriptions: $e");
    }
    
    // NEW: Delete Chats and messages
    try {
      final chatsSnap = await firestore.collection('chats').where('participants', arrayContains: uid).get();
      for (var chatDoc in chatsSnap.docs) {
        final msgsSnap = await chatDoc.reference.collection('messages').get();
        for (var msg in msgsSnap.docs) {
          await msg.reference.delete();
        }
        await chatDoc.reference.delete();
      }
    } catch (e) {
      print("[UserService] Error deleting chats: $e");
    }

    // Delete profile picture if exists
    try {
      await storage.ref().child('profile_pictures/$uid').delete();
    } catch (e) {
      print("[UserService] No profile picture to delete: $e");
    }

    // Finally delete user doc
    await userRef.delete();

    // 5. Delete from Firebase Auth
    await user.delete();
  }
}



