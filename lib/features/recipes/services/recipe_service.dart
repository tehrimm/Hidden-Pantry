import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/core/services/notification_service.dart';
import 'package:hidden_pantry_app/features/user/models/notification_model.dart';

class RecipeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Increments the view count for a specific recipe to track popularity.
  Future<void> incrementRecipeView(String recipeId) async {
    if (recipeId.isEmpty) {
      print("[RecipeService] Skip tracking: recipeId is empty");
      return;
    }
    
    print("[RecipeService] Incrementing view for: $recipeId");
    
    try {
      final docRef = _firestore.collection('recipe_metrics').doc(recipeId);
      
      await docRef.set({
        'viewCount': FieldValue.increment(1),
        'lastViewed': FieldValue.serverTimestamp(),
        'recipeId': recipeId, // Useful for queries
      }, SetOptions(merge: true));
      
      print("[RecipeService] View tracked successfully for $recipeId");
    } catch (e) {
      print("[RecipeService] Tracking failed for $recipeId: $e");
    }

  }

  Future<void> trackUserView(String recipeId, {Recipe? recipe, String? authorId, List<String>? tags}) async {
    try {
      User? user;
      try {
        user = FirebaseAuth.instance.currentUser;
      } catch (_) {
        return;
      }
      if (user == null) return;
      final uid = user.uid;
      final vRef = _firestore.collection('users').doc(uid).collection('views').doc(recipeId);
      await vRef.set({
        'count': FieldValue.increment(1),
        'lastViewed': FieldValue.serverTimestamp(),
        if (authorId != null) 'authorId': authorId,
        if (tags != null) 'tags': tags,
      }, SetOptions(merge: true));

      final t = tags ?? recipe?.tags ?? const <String>[];
      if (t.isNotEmpty) {
        final updates = <String, dynamic>{};
        for (final tag in t) {
          final key = 'tagWeights.${tag.toLowerCase()}';
          updates[key] = FieldValue.increment(1);
        }
        await _firestore.collection('users').doc(uid).set(updates, SetOptions(merge: true));
      }
    } catch (e) {
      print("[RecipeService] View personalization update failed: $e");
    }
  }

  /// Uploads an image to Firebase Storage and returns the download URL
  Future<String?> _uploadFile(String path, File file) async {
    try {
      final ref = FirebaseStorage.instance.ref().child(path);
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      print("[RecipeService] Upload failed for path $path: $e");
      return null;
    }
  }

  /// Handles the complete multi-step upload and Firestore persistence
  Future<void> uploadFullRecipe({
    required String title,
    required File? mainImage,
    required int prepTime,
    required int cookTime,
    required int servings,
    required String? difficulty,
    required List<String> tags,
    required List<Map<String, String>> ingredients,
    required List<DirectionStep> steps,
    required Map<String, String> nutrition,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User must be logged in to upload");

    final String recipeId = DateTime.now().millisecondsSinceEpoch.toString();
    
    // 1. Upload Main Image
    String? mainImageUrl;
    if (mainImage != null) {
      print("[RecipeService] Uploading main image: ${mainImage.path}");
      mainImageUrl = await _uploadFile('recipe_photos/$recipeId/main.jpg', mainImage);
      print("[RecipeService] Main image URL: $mainImageUrl");
    } else {
      print("[RecipeService] No main image provided");
    }

    // 2. Upload Step Images & Prepare Directions
    final List<String> directionsFlattened = [];
    final List<Map<String, dynamic>> stepsData = [];

    print("[RecipeService] Starting step images upload for ${steps.length} steps...");

    for (int i = 0; i < steps.length; i++) {
      final s = steps[i];
      String? stepImageUrl;
      if (s.image != null) {
        print("[RecipeService] Uploading image for step $i: ${s.image!.path}");
        stepImageUrl = await _uploadFile('recipe_photos/$recipeId/steps/step_$i.jpg', s.image!);
        print("[RecipeService] Step $i image URL: $stepImageUrl");
      } else {
        print("[RecipeService] No image for step $i");
      }
      
      directionsFlattened.add(s.text);
      stepsData.add({
        'text': s.text,
        'imageUrl': stepImageUrl,
      });
    }

    // 3. Prepare Final Recipe Map
    final recipeData = {
      'id': recipeId,
      'name': title,
      'name_search': title.toLowerCase(),
      'title': title,
      'imageUrl': mainImageUrl,
      'minutes': prepTime + cookTime,
      'prepTime': prepTime,
      'cookTime': cookTime,
      'servings': servings,
      'base_servings': servings,
      'difficulty': difficulty,
      'tags': tags,
      'author_id': user.uid,
      'author_name': user.displayName ?? "User",
      'author_profile_image_url': user.photoURL,
      'ingredients_parsed': ingredients.map((ing) {
        final rawQty = ing['quantity'] ?? '0';
        // Extract numeric part in case they typed "2 cups"
        final numericOnly = RegExp(r'[\d.]+').firstMatch(rawQty)?.group(0) ?? '0';
        return {
          'name': ing['name'],
          'quantity': double.tryParse(numericOnly) ?? 0.0,
          'unit': rawQty.replaceAll(numericOnly, '').trim(),
        };
      }).toList(),
      'ingredients': ingredients.map((e) => "${e['quantity'] ?? ''} ${e['name'] ?? ''}".trim()).toList(),
      'directions': directionsFlattened,
      'steps_detailed': stepsData,
      'nutrition': nutrition,
      'avg_rating': 0.0,
      'n_steps': steps.length,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // 4. Save to Firestore
    await _firestore.collection('recipes').doc(recipeId).set(recipeData);
  }

  // --- Reviews Logic ---

  /// Fetches reviews for a specific recipe
  Stream<QuerySnapshot> getReviews(String recipeId) {
    return _firestore
        .collection('reviews')
        .where('recipeId', isEqualTo: recipeId)
        .snapshots();
  }

  /// Adds a new review to Firestore
  Future<void> addReview(Map<String, dynamic> reviewData, {double? initialAvg, int? initialCount}) async {
    final recipeId = reviewData['recipeId']?.toString() ?? "";
    final userId = reviewData['userId']?.toString() ?? "";
    final rating = double.tryParse(reviewData['rating']?.toString() ?? "0") ?? 0.0;

    await _firestore.runTransaction((transaction) async {
      // 0. CHECK FOR EXISTING REVIEW
      final reviewId = "${userId}_${recipeId}";
      final reviewRef = _firestore.collection('reviews').doc(reviewId);
      final existingReview = await transaction.get(reviewRef);
      if (existingReview.exists) {
        throw Exception("You have already rated this recipe.");
      }

      // 1. READS FIRST
      DocumentSnapshot? recipeDoc;
      DocumentReference? recipeRef;
      if (recipeId.isNotEmpty) {
        recipeRef = _firestore.collection('recipes').doc(recipeId);
        recipeDoc = await transaction.get(recipeRef);
      }

      // 2. WRITES AFTER
      transaction.set(reviewRef, {
        ...reviewData,
        'createdAt': FieldValue.serverTimestamp(),
        'likes': 0,
        'likedBy': [],
      });

      if (recipeId.isNotEmpty && recipeRef != null) {
        double currentAvg = initialAvg ?? 0.0;
        int currentCount = initialCount ?? 0;

        if (recipeDoc != null && recipeDoc.exists) {
          final data = recipeDoc.data() as Map<String, dynamic>;
          final double fsAvg = double.tryParse(data['avg_rating']?.toString() ?? "0") ?? 0.0;
          final int fsCount = int.tryParse(data['review_count']?.toString() ?? "0") ?? 0;
          
          final int baseCount = initialCount ?? 0;
          
          if (fsCount >= baseCount) {
            currentAvg = fsAvg;
            currentCount = fsCount;
          } else {
            currentAvg = initialAvg ?? 0.0;
            currentCount = baseCount;
          }
        }
        
        final int finalCount = currentCount + 1;
        final double finalAvg = ((currentAvg * currentCount) + rating) / finalCount;

        transaction.set(recipeRef, {
          'id': recipeId,
          'avg_rating': finalAvg,
          'review_count': finalCount,
          'base_avg': initialAvg ?? 0.0,
          'base_count': initialCount ?? 0,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });

    // Send Notification to Recipe Author
    if (recipeId.isNotEmpty) {
      try {
        final recipeDoc = await _firestore.collection('recipes').doc(recipeId).get();
        if (recipeDoc.exists) {
          final recipeData = recipeDoc.data()!;
          final authorId = recipeData['author_id'];
          final recipeName = recipeData['name'] ?? 'your recipe';
          final senderName = reviewData['userName'] ?? 'Someone';

          if (authorId != null && authorId != userId) {
            NotificationService().sendNotification(
              recipientId: authorId,
              title: "New Review from $senderName",
              body: "$senderName commented on your recipe: $recipeName",
              type: NotificationType.comment,
              targetId: recipeId,
            );
          }
        }
      } catch (e) {
        print("Error sending review notification: $e");
      }
    }
  }

  /// Deletes a review and reverts the rating average
  Future<void> deleteReview(String recipeId, String userId) async {
    final reviewId = "${userId}_${recipeId}";
    final reviewRef = _firestore.collection('reviews').doc(reviewId);
    final recipeRef = _firestore.collection('recipes').doc(recipeId);

    await _firestore.runTransaction((transaction) async {
      final reviewDoc = await transaction.get(reviewRef);
      if (!reviewDoc.exists) return;

      final double rating = double.tryParse(reviewDoc.data()?['rating']?.toString() ?? "0") ?? 0.0;
      final recipeDoc = await transaction.get(recipeRef);

      if (recipeDoc.exists) {
        final data = recipeDoc.data() as Map<String, dynamic>;
        final int oldCount = int.tryParse(data['review_count']?.toString() ?? "0") ?? 0;
        final double oldAvg = double.tryParse(data['avg_rating']?.toString() ?? "0") ?? 0.0;
        final int baseCount = int.tryParse(data['base_count']?.toString() ?? "0") ?? 0;
        final double baseAvg = double.tryParse(data['base_avg']?.toString() ?? "0") ?? 0.0;

        if (oldCount > baseCount) {
          final int newCount = oldCount - 1;
          double newAvg = baseAvg;
          if (newCount > baseCount) {
             newAvg = ((oldAvg * oldCount) - rating) / newCount;
          }
          
          transaction.update(recipeRef, {
            'avg_rating': newAvg,
            'review_count': newCount,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      transaction.delete(reviewRef);
    });
  }

  /// Toggles a like on a review
  Future<void> toggleLike(String reviewId, String userId) async {
    final docRef = _firestore.collection('reviews').doc(reviewId);
    final doc = await docRef.get();
    if (!doc.exists) return;

    List<String> likedBy = List<String>.from(doc.data()?['likedBy'] ?? []);
    if (likedBy.contains(userId)) {
      await docRef.update({
        'likes': FieldValue.increment(-1),
        'likedBy': FieldValue.arrayRemove([userId]),
      });
    } else {
      await docRef.update({
        'likes': FieldValue.increment(1),
        'likedBy': FieldValue.arrayUnion([userId]),
      });
    }
  }

  /// Adds a reply to a review
  Future<void> addReply(String reviewId, Map<String, dynamic> replyData) async {
    await _firestore
        .collection('reviews')
        .doc(reviewId)
        .collection('replies')
        .add({
      ...replyData,
      'createdAt': FieldValue.serverTimestamp(),
      'likes': 0,
      'likedBy': [],
    });

    // Send Notification to Review Author
    _notifyReviewAuthor(reviewId, "replied to your review");
  }

  Future<void> _notifyReviewAuthor(String reviewId, String action) async {
    try {
      final reviewDoc = await _firestore.collection('reviews').doc(reviewId).get();
      if (!reviewDoc.exists) return;
      
      final authorId = reviewDoc.data()?['userId'];
      final user = FirebaseAuth.instance.currentUser;

      if (authorId != null && authorId != user?.uid) {
        NotificationService().sendNotification(
          recipientId: authorId,
          title: "Reply from ${user?.displayName ?? 'Someone'}",
          body: "${user?.displayName ?? 'Someone'} $action",
          type: NotificationType.reply,
          targetId: reviewId,
        );
      }
    } catch (e) {
      print("Error notifying review author: $e");
    }
  }



  /// Deletes a specific reply
  Future<void> deleteReply(String reviewId, String replyId) async {
    await _firestore
        .collection('reviews')
        .doc(reviewId)
        .collection('replies')
        .doc(replyId)
        .delete();
  }

  /// Toggles a like on a reply
  Future<void> toggleReplyLike(String reviewId, String replyId, String userId) async {
    final docRef = _firestore
        .collection('reviews')
        .doc(reviewId)
        .collection('replies')
        .doc(replyId);
    
    final doc = await docRef.get();
    if (!doc.exists) return;

    List<String> likedBy = List<String>.from(doc.data()?['likedBy'] ?? []);
    if (likedBy.contains(userId)) {
      await docRef.update({
        'likes': FieldValue.increment(-1),
        'likedBy': FieldValue.arrayRemove([userId]),
      });
    } else {
      await docRef.update({
        'likes': FieldValue.increment(1),
        'likedBy': FieldValue.arrayUnion([userId]),
      });
    }
  }

  /// Fetches replies for a specific review
  Stream<QuerySnapshot> getReplies(String reviewId) {
    return _firestore
        .collection('reviews')
        .doc(reviewId)
        .collection('replies')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  // --- Cookbooks / Saved Recipes ---

  /// Fetches cookbooks for a user
  Stream<List<Map<String, dynamic>>> getUserCookbooks(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('cookbooks')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());
  }

  /// Creates a new cookbook
  Future<void> createCookbook(String userId, String title, String description) async {
    print("[RecipeService] Creating cookbook for user: $userId, title: $title");
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('cookbooks')
          .add({
        'title': title,
        'description': description,
        'recipeIds': [],
        'imageUrl': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
      print("[RecipeService] Cookbook created successfully");
    } catch (e) {
      print("[RecipeService] Error creating cookbook: $e");
      rethrow;
    }
  }

  /// Adds a recipe to a cookbook
  Future<void> addRecipeToCookbook(String userId, String cookbookId, String recipeId, String? recipeImageUrl) async {
    final docRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('cookbooks')
        .doc(cookbookId);

    await docRef.update({
      'recipeIds': FieldValue.arrayUnion([recipeId]),
      'imageUrl': recipeImageUrl, // Update with latest added recipe image
    });
  }

  /// Specialized helper to get or create the default 'Favorite' cookbook
  Future<String> getOrCreateFavoriteCookbook(String userId) async {
    final snap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('cookbooks')
        .where('title', isEqualTo: 'Favorite')
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty) {
      return snap.docs.first.id;
    }

    // Create it if missing
    final docRef = await _firestore
        .collection('users')
        .doc(userId)
        .collection('cookbooks')
        .add({
      'title': 'Favorite',
      'description': 'My default favorite recipes.',
      'recipeIds': [],
      'imageUrl': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    return docRef.id;
  }

  /// Removes a recipe from a specific cookbook
  Future<void> removeRecipeFromCookbook(String userId, String cookbookId, String recipeId) async {
    final docRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('cookbooks')
        .doc(cookbookId);

    await docRef.update({
      'recipeIds': FieldValue.arrayRemove([recipeId]),
    });
  }

  /// Checks which cookbooks contain this recipe
  Future<List<String>> getCookbookIdsForRecipe(String userId, String recipeId) async {
    final snap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('cookbooks')
        .where('recipeIds', arrayContains: recipeId)
        .get();
    
    return snap.docs.map((doc) => doc.id).toList();
  }

  /// Helper to check if a recipe is bookmarked at all
  Future<bool> isRecipeBookmarked(String userId, String recipeId) async {
    final snap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('cookbooks')
        .where('recipeIds', arrayContains: recipeId)
        .limit(1)
        .get();
    
    return snap.docs.isNotEmpty;
  }

  // --- Likes Logic ---

  /// Toggles a like for a recipe
  Future<void> toggleRecipeLike(String userId, String recipeId) async {
    final docRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('likes')
        .doc(recipeId);

    final doc = await docRef.get();
    if (doc.exists) {
      await docRef.delete();
      print("[RecipeService] Recipe $recipeId unliked");
    } else {
      await docRef.set({
        'likedAt': FieldValue.serverTimestamp(),
      });
      print("[RecipeService] Recipe $recipeId liked");

      // Trigger Notification to Recipe Owner
      _notifyRecipeOwner(recipeId, "liked your recipe");
    }
  }

  Future<void> _notifyRecipeOwner(String recipeId, String action) async {
    try {
      final recipeDoc = await _firestore.collection('recipes').doc(recipeId).get();
      if (!recipeDoc.exists) return;
      
      final authorId = recipeDoc.data()?['authorId'] ?? recipeDoc.data()?['author_id'];
      final recipeName = recipeDoc.data()?['name'] ?? recipeDoc.data()?['title'] ?? 'your recipe';

      final user = FirebaseAuth.instance.currentUser;
      if (authorId != null && authorId.isNotEmpty && authorId != user?.uid) {
        NotificationService().sendNotification(
          recipientId: authorId,
          title: "Recipe Liked by ${user?.displayName ?? 'Someone'}",
          body: "${user?.displayName ?? 'Someone'} $action: $recipeName",
          type: NotificationType.like,
          targetId: recipeId,
        );
      }
    } catch (e) {
      print("Error notifying recipe owner: $e");
    }
  }

  /// Checks if a recipe is liked by a user
  Future<bool> isRecipeLiked(String userId, String recipeId) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('likes')
        .doc(recipeId)
        .get();
    return doc.exists;
  }

  /// Gets all liked recipe IDs for a user
  Future<List<String>> getLikedRecipeIds(String userId) async {
    final snap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('likes')
        .get();
    return snap.docs.map((doc) => doc.id).toList();
  }

  /// Fetches a single recipe from Firestore by its ID.
  Future<Recipe?> getRecipeById(String recipeId) async {
    try {
      final doc = await _firestore
          .collection('recipes')
          .doc(recipeId)
          .get()
          .timeout(const Duration(seconds: 3)); // Fail fast if offline
      if (!doc.exists) return null;
      return Recipe.fromJson(doc.data()!);
    } catch (e) {
      print("[RecipeService] Error fetching recipe $recipeId: $e");
      return null;
    }
  }

  /// Fetches multiple recipes by their IDs (chunks of 10 for Firestore limit)
  Future<List<Recipe>> getRecipesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    
    final List<Recipe> results = [];
    
    // Firestore 'whereIn' supports max 10 values
    for (var i = 0; i < ids.length; i += 10) {
      final end = (i + 10 < ids.length) ? i + 10 : ids.length;
      final chunk = ids.sublist(i, end);
      
      try {
        final snap = await _firestore
            .collection('recipes')
            .where('id', whereIn: chunk)
            .get();
            
        results.addAll(snap.docs.map((doc) => Recipe.fromJson(doc.data())));
      } catch (e) {
        print("[RecipeService] Error fetching chunk of recipes: $e");
      }
    }
    
    return results;
  }

  Future<int> countRecipesByAuthor(String authorId) async {
    try {
      final snap = await _firestore
          .collection('recipes')
          .where('author_id', isEqualTo: authorId)
          .get();
      return snap.docs.length;
    } catch (e) {
      print("[RecipeService] Error counting recipes for author $authorId: $e");
      return 0;
    }
  }

  /// Searches Firestore recipes by name (case-insensitive substring)
  Future<List<Recipe>> searchRecipes(String query, {int limit = 20}) async {
    if (query.isEmpty) return [];
    
    final searchKey = query.toLowerCase();
    
    try {
      // Note: Firestore doesn't support native partial string matching without an external indexer like Algolia.
      // However, for small/medium datasets, we can use the \uf8ff prefix trick or just startsWith.
      // For more robust "contains" search, we'd normally need Algolia, but here 
      // we'll implement a 'starts with' query which is often sufficient for search.
      final snap = await _firestore
          .collection('recipes')
          .where('name_search', isGreaterThanOrEqualTo: searchKey)
          .where('name_search', isLessThanOrEqualTo: '$searchKey\uf8ff')
          .limit(limit)
          .get();
          
      return snap.docs.map((doc) => Recipe.fromJson(doc.data())).toList();
    } catch (e) {
      print("[RecipeService] Error searching Firestore recipes: $e");
      return [];
    }
  }

  /// Deletes a recipe from Firestore and its images from Firebase Storage
  Future<void> deleteRecipe(String recipeId) async {
    print("[RecipeService] Requesting deletion of recipe: $recipeId");
    try {
      // 1. Delete Firestore Document
      await _firestore.collection('recipes').doc(recipeId).delete();
      print("[RecipeService] Firestore document deleted.");

      // 2. Delete images from Storage
      final storageRef = FirebaseStorage.instance.ref().child('recipe_photos/$recipeId');
      final listResult = await storageRef.listAll();
      
      // Delete main image and any other files at the root of the recipe folder
      for (var item in listResult.items) {
        await item.delete();
      }
      
      // Delete step images in the subfolder
      final stepsRef = storageRef.child('steps');
      try {
        final stepsList = await stepsRef.listAll();
        for (var item in stepsList.items) {
          await item.delete();
        }
      } catch (e) {
        // Steps folder might not exist if no step images were uploaded
        print("[RecipeService] Note: No steps folder found or error listing it: $e");
      }
      
      print("[RecipeService] Storage images deleted.");
    } catch (e) {
      print("[RecipeService] Error deleting recipe $recipeId: $e");
      rethrow;
    }
  }
}



