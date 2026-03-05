import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hidden_pantry_app/core/constants/api_constants.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_api_service.dart';
import 'package:hidden_pantry_app/core/services/notification_service.dart';
import 'package:hidden_pantry_app/features/user/models/notification_model.dart';

class FollowService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Toggles follow status for an author, or enforces it if shouldFollow is provided
  Future<void> toggleFollow(String authorId, {bool? shouldFollow, String? authorName, String? photoUrl}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userFollowingRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('following')
        .doc(authorId);
    
    final authorFollowerRef = _firestore
        .collection('users')
        .doc(authorId)
        .collection('followers')
        .doc(user.uid);

    final doc = await userFollowingRef.get();
    
    final authorRef = _firestore.collection('users').doc(authorId);
    final userRef = _firestore.collection('users').doc(user.uid);

    bool isCurrentlyFollowing = doc.exists;
    bool actionIsFollow = shouldFollow ?? !isCurrentlyFollowing;

    if (!actionIsFollow) {
      if (!isCurrentlyFollowing) return; // Already unfollowed
      // Unfollow
      await _firestore.runTransaction((transaction) async {
        transaction.delete(userFollowingRef);
        transaction.delete(authorFollowerRef); // Remove from author's followers
        transaction.set(authorRef, {'followerCount': FieldValue.increment(-1)}, SetOptions(merge: true));
        transaction.set(userRef, {'followingCount': FieldValue.increment(-1)}, SetOptions(merge: true));
      });
    } else {
      if (isCurrentlyFollowing) return; // Already followed
      // Follow
      await _firestore.runTransaction((transaction) async {
        transaction.set(userFollowingRef, {
          'followedAt': FieldValue.serverTimestamp(),
          'authorId': authorId,
          'authorName': authorName, // Store metadata
          'photoUrl': photoUrl,
        });
        transaction.set(authorFollowerRef, { // Add to author's followers
          'followedAt': FieldValue.serverTimestamp(),
          'userId': user.uid,
          'userName': user.displayName, // Store follower metadata too
          'photoUrl': user.photoURL,
        });
        
        // Ensure author doc exists for count (might be a JSON author)
        // If it's a new doc, set the name if we have it
        transaction.set(authorRef, {
            'followerCount': FieldValue.increment(1),
            if (authorName != null) 'fullName': authorName, // Fallback name for placeholder
        }, SetOptions(merge: true));
        
        transaction.set(userRef, {'followingCount': FieldValue.increment(1)}, SetOptions(merge: true));
        
        // Trigger Notification
        NotificationService().sendNotification(
          recipientId: authorId,
          title: "New Follower: ${user.displayName ?? 'Someone'}",
          body: "${user.displayName ?? 'Someone'} started following you.",
          type: NotificationType.follow,
          targetId: user.uid,
        );
      });
    }
  }

  /// Fetches real-time social stats for an author from Firestore
  Future<Map<String, int>> getPublicAuthorStats(String authorId) async {
    final doc = await _firestore.collection('users').doc(authorId).get();
    if (!doc.exists) return {'followers': 0, 'following': 0};
    
    final data = doc.data()!;
    return {
      'followers': int.tryParse(data['followerCount']?.toString() ?? '0') ?? 0,
      'following': int.tryParse(data['followingCount']?.toString() ?? '0') ?? 0,
    };
  }

  /// Checks if the current user is following an author
  Future<bool> isFollowing(String authorId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final doc = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('following')
        .doc(authorId)
        .get();
    
    return doc.exists;
  }

  /// Gets the list of author IDs the user is following
  Future<List<String>> getFollowedAuthorIds() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final snap = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('following')
        .get();
    
    return snap.docs.map((doc) => doc.id).toList();
  }

  /// Streams the following list for real-time Home Screen updates
  Stream<List<String>> streamFollowedAuthorIds() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('following')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.id).toList());
  }

  /// Fetch full user profiles for the "Following" list
  Future<List<Map<String, dynamic>>> getFollowingProfiles(String uid) async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('following')
          // .orderBy('followedAt', descending: true)
          .get();

      if (snap.docs.isEmpty) return [];

      List<Map<String, dynamic>> profiles = [];
      final api = RecipeApiService(baseUrl: ApiConstants.baseUrl);

      for (var doc in snap.docs) {
        final authorId = doc.id;
        final relData = doc.data(); 
        
        var userDoc = await _firestore.collection('nutritionists').doc(authorId).get();
        if (!userDoc.exists) {
          userDoc = await _firestore.collection('users').doc(authorId).get();
        }

        Map<String, dynamic> data;
        if (userDoc.exists) {
          data = userDoc.data()!;
          data['uid'] = authorId;
        } else {
          data = {'uid': authorId};
        }

        // Logic to determine/fetch name
        String? finalName = data['fullName'] ?? data['name'];
        if (finalName == null || finalName == 'User') {
           // 1. Try metadata from following doc
           if (relData.containsKey('authorName')) {
              finalName = relData['authorName'];
           } 
           // 2. Fallback: Fetch from API (Self-healing for legacy follows)
           else {
             try {
               // 2. Fallback: Fetch from API (Stats endpoint)
               final stats = await api.getAuthorStats(authorId);
               if (stats.containsKey('name')) {
                 finalName = stats['name'];
               } 
               
               // 3. Deep Fallback: If stats didn't have it, try fetching one recipe
               if (finalName == null || data['photoUrl'] == null) {
                  final recipes = await api.fetchRecipesByAuthor(authorId, limit: 1);
                  if (recipes.isNotEmpty) {
                    if (finalName == null && recipes.first.authorName != null) {
                      finalName = recipes.first.authorName;
                    }
                    if (data['photoUrl'] == null && recipes.first.authorProfileImageUrl != null) {
                      data['photoUrl'] = recipes.first.authorProfileImageUrl;
                    }
                  }
               }

               // Self-heal: Update the placeholder doc
               final Map<String, dynamic> updates = {};
               if (finalName != null && (data['fullName'] == null || data['fullName'] == 'User')) {
                 updates['fullName'] = finalName;
               }
               if (data['photoUrl'] != null && (userDoc.data()?['photoUrl'] == null)) {
                 updates['photoUrl'] = data['photoUrl'];
               }
               
               if (updates.isNotEmpty && userDoc.exists) {
                   _firestore.collection('users').doc(authorId).set(updates, SetOptions(merge: true));
               }
             } catch (e) {
               print("API fallback failed for $authorId: $e");
             }
           }
        }
        
        data['fullName'] = finalName ?? 'Unknown Author';

        // Logic for photo
        if (data['photoUrl'] == null && relData.containsKey('photoUrl')) {
           data['photoUrl'] = relData['photoUrl'];
        }
        
        profiles.add(data);
      }
      return profiles;
    } catch (e) {
      print("Error fetching following profiles: $e");
      return [];
    }
  }

  /// Fetch full user profiles for the "Followers" list
  Future<List<Map<String, dynamic>>> getFollowerProfiles(String uid) async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('followers')
          // .orderBy('followedAt', descending: true) // Temporarily removed for debugging
          .get();

      if (snap.docs.isEmpty) return [];

      List<Map<String, dynamic>> profiles = [];
      for (var doc in snap.docs) {
        final followerId = doc.id;
        var userDoc = await _firestore.collection('users').doc(followerId).get();
        if (!userDoc.exists) {
           userDoc = await _firestore.collection('nutritionists').doc(followerId).get();
        }

        if (userDoc.exists) {
          final data = userDoc.data()!;
          data['uid'] = followerId;
          profiles.add(data);
        }
      }
      return profiles;
    } catch (e) {
      print("Error fetching follower profiles: $e");
      return [];
    }
  }
}
