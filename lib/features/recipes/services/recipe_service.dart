import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/core/services/notification_service.dart';
import 'package:hidden_pantry_app/features/user/models/notification_model.dart';
import 'package:hidden_pantry_app/core/services/view_mode_service.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_api_service.dart';
import 'package:hidden_pantry_app/core/constants/api_constants.dart';

class RecipeService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final ViewModeService _viewMode;
  final RecipeApiService _api;
  final FirebaseStorage _storage;

  RecipeService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    RecipeApiService? api,
    ViewModeService? viewMode,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _api = api ?? const RecipeApiService(baseUrl: ApiConstants.baseUrl),
        _viewMode = viewMode ?? ViewModeService(),
        _storage = storage ?? FirebaseStorage.instance;

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
        user = _auth.currentUser;
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

      // Track global engagement for trending
      _trackEngagement(recipeId, 'view');
    } catch (e) {
      print("[RecipeService] View personalization update failed: $e");
    }
  }

  /// Uploads an image to Firebase Storage and returns the download URL
  Future<String?> _uploadFile(String path, File file) async {
    try {
      final ref = _storage.ref().child(path);
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      print("[RecipeService] Upload failed for path $path: $e");
      return null;
    }
  }

  /// Handles the complete multi-step upload and Firestore persistence.
  /// If [recipeId] is provided, it updates the existing recipe.
  Future<void> uploadFullRecipe({
    String? recipeId,
    required String title,
    required File? mainImage,
    required List<Map<String, dynamic>> ingredients,
    required int prepTime,
    required int cookTime,
    required int servings,
    required String difficulty,
    required List<String> tags,
    required List<DirectionStep> steps,
    required Map<String, String> nutrition,
    bool isPublic = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User must be logged in to upload");

    final bool isUpdate = recipeId != null;
    final String finalRecipeId = recipeId ?? DateTime.now().millisecondsSinceEpoch.toString();
    
    // 0. Fetch existing recipe if updating to preserve old image URLs
    Recipe? existing;
    if (isUpdate) {
      existing = await getRecipeById(finalRecipeId);
    }

    // 1. Upload Main Image (or preserve existing)
    String? mainImageUrl = existing?.imageUrl;
    if (mainImage != null) {
      print("[RecipeService] Uploading main image: ${mainImage.path}");
      mainImageUrl = await _uploadFile('recipe_photos/$finalRecipeId/main.jpg', mainImage);
      print("[RecipeService] Main image URL: $mainImageUrl");
    }

    // 2. Upload Step Images & Prepare Directions
    final List<String> directionsFlattened = [];
    final List<Map<String, dynamic>> stepsData = [];

    print("[RecipeService] Processing ${steps.length} steps...");

    for (int i = 0; i < steps.length; i++) {
      final s = steps[i];
      String? stepImageUrl = s.imageUrl; // Use existing URL if provided

      if (s.image != null) {
        print("[RecipeService] Uploading image for step $i: ${s.image!.path}");
        stepImageUrl = await _uploadFile('recipe_photos/$finalRecipeId/steps/step_$i.jpg', s.image!);
        print("[RecipeService] Step $i image URL: $stepImageUrl");
      }
      
      directionsFlattened.add(s.text);
      stepsData.add({
        'text': s.text,
        'imageUrl': stepImageUrl,
      });
    }

    // 3. Prepare Final Recipe Map
    final recipeData = {
      'id': finalRecipeId,
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
        final rawQty = (ing['quantity'] ?? '').toString().trim();
        final name = (ing['name'] ?? '').toString().trim();
        
        final combined = rawQty.isEmpty ? name : "$rawQty $name";
        final parsed = Recipe.parseIngredient(combined);
        
        return parsed?.toJson() ?? {
          'name': name,
          'quantity': 1.0,
          'unit': '',
        };
      }).toList(),

      'ingredients': ingredients.map((e) => "${e['quantity'] ?? ''} ${e['name'] ?? ''}".trim()).toList(),
      'directions': directionsFlattened,
      'steps_detailed': stepsData,
      'nutrition': nutrition,
      'avg_rating': existing?.avgRating ?? 0.0,
      'review_count': existing?.reviewCount ?? 0,
      'n_steps': steps.length,
      'is_nutritionist_recipe': await _viewMode.isNutritionist(),
      'is_public': isPublic,
      if (!isUpdate) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // 4. Save to Firestore
    await _firestore.collection('recipes').doc(finalRecipeId).set(recipeData, SetOptions(merge: true));

    // 5. Increment recipe_count on Author Profile (Only for NEW recipes)
    if (!isUpdate) {
      try {
        final isNutr = recipeData['is_nutritionist_recipe'] as bool? ?? false;
        final coll = isNutr ? 'nutritionists' : 'users';
        await _firestore.collection(coll).doc(user.uid).set({
          'recipe_count': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        print("[RecipeService] Author recipe_count incremented in $coll");
      } catch (e) {
        print("[RecipeService] Failed to increment author recipe_count: $e");
      }
    }
  }

  // --- Reviews Logic ---

  /// Fetches reviews for a specific recipe
  Stream<QuerySnapshot> getReviews(String recipeId) {
    return _firestore
        .collection('reviews')
        .where('recipeId', isEqualTo: recipeId)
        .snapshots();
  }

  /// Checks if a user has already reviewed a specific recipe
  Future<bool> hasUserReviewed(String recipeId, String userId) async {
    if (recipeId.isEmpty || userId.isEmpty) return false;
    final doc = await _firestore.collection('reviews').doc("${userId}_${recipeId}").get();
    return doc.exists;
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
      final authorId = recipeDoc?.data() != null ? (recipeDoc!.data() as Map<String, dynamic>)['author_id'] : null;

      transaction.set(reviewRef, {
        ...reviewData,
        'authorId': authorId, // Store the authorId in the review for easier dashboard querying
        'createdAt': FieldValue.serverTimestamp(),
        'likes': 0,
        'likedBy': [],
      });

      if (recipeId.isNotEmpty && recipeRef != null && recipeDoc != null) {
        double currentAvg = initialAvg ?? 0.0;
        int currentCount = initialCount ?? 0;

        double fsAvg = 0.0;
        int fsCount = 0;

        if (recipeDoc.exists) {
          final data = recipeDoc.data() as Map<String, dynamic>;
          fsAvg = double.tryParse(data['avg_rating']?.toString() ?? "0") ?? 0.0;
          fsCount = int.tryParse(data['review_count']?.toString() ?? "0") ?? 0;
        }
        
        final int baseCount = initialCount ?? 0;
        
        if (fsCount > 0 || recipeDoc.exists) {
          currentAvg = fsAvg;
          currentCount = fsCount;
        }
        
        if (fsCount < baseCount && baseCount > 0) {
          currentAvg = initialAvg ?? 0.0;
          currentCount = baseCount;
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
          final isNutr = recipeData['is_nutritionist_recipe'] as bool? ?? false;
          final double ratingVal = double.tryParse(reviewData['rating']?.toString() ?? "0") ?? 0.0;

          if (authorId != null && authorId != userId) {
            NotificationService().sendNotification(
              recipientId: authorId,
              title: "New Review from $senderName",
              body: "$senderName commented on your recipe: $recipeName",
              type: NotificationType.comment,
              targetId: recipeId,
            );
          }

          try {
            if (authorId != null && authorId.toString().isNotEmpty) {
              final authorColl = isNutr ? 'nutritionists' : 'users';
              await _firestore.collection(authorColl).doc(authorId).set({
                'total_rating_sum': FieldValue.increment(ratingVal),
                'total_review_count': FieldValue.increment(1),
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
            }
          } catch (e) {
            print("Author stats update skipped: $e");
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

    // Check if there are any replies to this review to decide between hard and soft delete
    final repliesSnap = await reviewRef.collection('replies').limit(1).get();
    final hasReplies = repliesSnap.docs.isNotEmpty;

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

          // 3. Update Author Stats
          final rData = recipeDoc.data() as Map<String, dynamic>;
          final authorId = rData['author_id'];
          final isNutr = rData['is_nutritionist_recipe'] as bool? ?? false;
          if (authorId != null) {
            final authorRef = _firestore.collection(isNutr ? 'nutritionists' : 'users').doc(authorId);
            transaction.set(authorRef, {
              'total_rating_sum': FieldValue.increment(-rating),
              'total_review_count': FieldValue.increment(-1),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
        }
      }

      if (hasReplies) {
        // Soft delete: Keep the doc to anchor the replies, but redact content
        transaction.update(reviewRef, {
          'comment': 'This comment was deleted by the author.',
          'isDeleted': true,
          'imageUrl': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Hard delete: No replies, safe to remove completely
        transaction.delete(reviewRef);
      }
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
      // Send Notification to Review Author
      _notifyReviewAuthor(reviewId, "liked your review");
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
      final recipeId = reviewDoc.data()?['recipeId']; // Get the recipeId
      final user = _auth.currentUser;

      if (authorId != null && authorId != user?.uid && recipeId != null) {
        NotificationService().sendNotification(
          recipientId: authorId,
          title: "Reply from ${user?.displayName ?? 'Someone'}",
          body: "${user?.displayName ?? 'Someone'} $action",
          type: NotificationType.reply,
          targetId: recipeId, // Pass recipeId instead of reviewId
        );
      }
    } catch (e) {
      print("Error notifying review author: $e");
    }
  }



  /// Deletes a specific reply
  Future<void> deleteReply(String reviewId, String replyId) async {
    // Replies don't have children in the current flat structure, so hard delete is safe
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
      // Send Notification to Reply Author
      _notifyReplyAuthor(reviewId, replyId, "liked your reply");
    }
  }

  Future<void> _notifyReplyAuthor(String reviewId, String replyId, String action) async {
    try {
      final replyDoc = await _firestore
          .collection('reviews')
          .doc(reviewId)
          .collection('replies')
          .doc(replyId)
          .get();
      if (!replyDoc.exists) return;
      
      final authorId = replyDoc.data()?['userId'];
      final user = _auth.currentUser;

      if (authorId != null && authorId != user?.uid) {
        // We need the recipeId from the parent review to navigate correctly
        final reviewDoc = await _firestore.collection('reviews').doc(reviewId).get();
        final recipeId = reviewDoc.data()?['recipeId'];

        if (recipeId != null) {
          NotificationService().sendNotification(
            recipientId: authorId,
            title: "Like from ${user?.displayName ?? 'Someone'}",
            body: "${user?.displayName ?? 'Someone'} $action",
            type: NotificationType.reply,
            targetId: recipeId, // Pass recipeId instead of reviewId
          );
        }
      }
    } catch (e) {
      print("Error notifying reply author: $e");
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
    // 1. Fetch all cookbooks to check case-insensitively
    final snap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('cookbooks')
        .get();

    for (var doc in snap.docs) {
      final title = (doc.data()['title']?.toString() ?? '').toLowerCase();
      if (title == 'favorite') {
        return doc.id;
      }
    }

    // 2. Create it if missing (always use capitalized 'Favorite')
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

      // Track global engagement for trending
      _trackEngagement(recipeId, 'like');

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

      final user = _auth.currentUser;
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
          .timeout(const Duration(seconds: 3));

      if (!doc.exists) return null;
      
      final data = doc.data()!;
      data['id'] = doc.id;
      
      // Check if this is a partial document (like we do in getRecipesByIds)
      final hasName = data['name'] != null || data['title'] != null;
      if (!hasName) {
        print("[RecipeService] Found partial doc for $recipeId in single fetch, ignoring to allow API fallback.");
        return null;
      }
      
      return Recipe.fromJson(data);
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
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
            
        // 1. Process valid docs from Firestore
        final List<String> validFetchedIds = [];
        final Map<String, Map<String, dynamic>> partialDocs = {};
        
        for (var doc in snap.docs) {
          final data = doc.data();
          data['id'] = doc.id;
          
          // Check if this is a partial document (e.g. created by merge operations for reviews)
          final hasName = data['name'] != null || data['title'] != null;
          
          if (hasName) {
            results.add(Recipe.fromJson(data));
            validFetchedIds.add(doc.id);
          } else {
            // It's a partial doc. Don't add to results, let it be fetched from API
            print("[RecipeService] Found partial doc for ${doc.id}, will fetch from API.");
            partialDocs[doc.id] = data;
          }
        }
        
        // 2. Identify missing IDs (likely from API or partial docs)
        final missingIds = chunk.where((id) => !validFetchedIds.contains(id)).toList();
        
        // 3. Fetch missing from API in parallel
        if (missingIds.isNotEmpty) {
          final apiResults = await Future.wait(missingIds.map((id) async {
            try {
              return await _api.getRecipeById(id);
            } catch (e) {
              print("[RecipeService] API fallback failed for $id: $e");
              if (partialDocs.containsKey(id)) {
                final data = partialDocs[id]!;
                data['name'] = "Recipe Unavailable";
                data['minutes'] = 0;
                return Recipe.fromJson(data);
              } else {
                return Recipe(
                  id: id, 
                  name: "Recipe Unavailable", 
                  minutes: 0, 
                  avgRating: 0.0, 
                  authorName: "System",
                  imageUrl: null
                );
              }
            }
          }));
          results.addAll(apiResults);
        }
      } catch (e) {
        print("[RecipeService] Error fetching chunk of recipes: $e");
      }
    }
    
    // Maintain result order based on input IDs
    final Map<String, Recipe> resultMap = {for (var r in results) r.id: r};
    return ids.where((id) => resultMap.containsKey(id)).map((id) => resultMap[id]!).toList();
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
  /// Excludes nutritionist recipes from public search.
  Future<List<Recipe>> searchRecipes(
    String query, {
    int limit = 20,
    List<String>? ingredients,
    int? maxMinutes,
    List<String>? tags,
  }) async {
    if (query.isEmpty && (ingredients == null || ingredients.isEmpty) && (tags == null || tags.isEmpty)) {
      return [];
    }
    
    final searchKey = query.toLowerCase().trim();
    
    try {
      // 1. Initial query: Fetch a larger pool for local text filtering
      Query<Map<String, dynamic>> baseQuery = _firestore.collection('recipes')
          .limit(limit * 20); // Fetch up to 400 to allow deep local filtering

      // 2. Filter out private recipes (unless owned by the current user)
      final snap = await baseQuery.get(); 
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
          
      var results = snap.docs
          .map((doc) => Recipe.fromJson(doc.data()))
          .where((r) => r.isPublic || (currentUserId != null && r.authorId == currentUserId))
          .toList();

      // If the user is logged in, ensure we ALSO explicitly fetch all of their own recipes
      // because the arbitrary limit(400) above might have missed them!
      if (currentUserId != null) {
        final mySnap = await _firestore.collection('recipes')
            .where('author_id', isEqualTo: currentUserId)
            .get();
        final myRecipes = mySnap.docs.map((doc) => Recipe.fromJson(doc.data())).toList();
        
        // Merge without duplicates
        final existingIds = results.map((r) => r.id).toSet();
        for (var r in myRecipes) {
          if (!existingIds.contains(r.id)) {
            results.add(r);
            existingIds.add(r.id);
          }
        }
      }

      // 2.5 Local Substring Search (Because Firestore doesn't support .contains())
      if (searchKey.isNotEmpty) {
        results = results.where((r) => 
          r.name.toLowerCase().contains(searchKey) ||
          r.ingredients.any((i) => i.name.toLowerCase().contains(searchKey)) ||
          r.tags.any((t) => t.toLowerCase().contains(searchKey))
        ).toList();
      }

      // 3. Local filtering for ingredients/tags/maxMinutes
      if (maxMinutes != null) {
        results = results.where((r) => r.minutes > 0 && r.minutes <= maxMinutes).toList();
      }

      if (tags != null && tags.isNotEmpty) {
        results = results.where((r) {
          final rTags = r.tags.map((t) => t.toLowerCase()).toList();
          return tags.any((st) => rTags.contains(st.toLowerCase()));
        }).toList();
      }

      if (ingredients != null && ingredients.isNotEmpty) {
        results = results.where((r) {
          final rIngs = r.ingredients.map((i) => i.name.toLowerCase()).toList();
          final rName = r.name.toLowerCase();
          return ingredients.every((si) {
            final s = si.toLowerCase();
            return rIngs.any((ri) => ri.contains(s)) || rName.contains(s);
          });
        }).toList();
      }
          
      return results.take(limit).toList();
    } catch (e) {
      print("[RecipeService] Error searching Firestore recipes: $e");
      return [];
    }
  }

  /// Deletes a recipe from Firestore and its images from Firebase Storage
  Future<void> deleteRecipe(String recipeId) async {
    print("[RecipeService] Requesting deletion of recipe: $recipeId");
    try {
      // 0. Fetch metadata before deletion
      final doc = await _firestore.collection('recipes').doc(recipeId).get();
      final data = doc.data();
      final authorId = data?['author_id'];
      final isNutr = data?['is_nutritionist_recipe'] as bool? ?? false;

      // 1. Delete Firestore Document
      await _firestore.collection('recipes').doc(recipeId).delete();
      print("[RecipeService] Firestore document deleted.");

      // 2. Decrement recipe_count on Author Profile
      if (authorId != null) {
        final coll = isNutr ? 'nutritionists' : 'users';
        await _firestore.collection(coll).doc(authorId).update({
          'recipe_count': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        }).catchError((e) => print("[RecipeService] Error decrementing recipe_count: $e"));
      }

      // 2. Delete images from Storage
      final storageRef = _storage.ref().child('recipe_photos/$recipeId');
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

  /// Synchronizes author information across all their recipes.
  /// Useful when a user/nutritionist updates their profile name or photo.
  Future<void> syncAuthorName(String authorId, String newName, String? photoUrl) async {
    print("[RecipeService] Syncing author info for $authorId -> $newName");
    try {
      final batch = _firestore.batch();
      final recipes = await _firestore
          .collection('recipes')
          .where('author_id', isEqualTo: authorId)
          .get();
      
      print("[RecipeService] Found ${recipes.docs.length} recipes to update");
      
      for (var doc in recipes.docs) {
        batch.update(doc.reference, {
          'author_name': newName,
          if (photoUrl != null) 'author_profile_image_url': photoUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
      print("[RecipeService] Author info sync completed successfully");
    } catch (e) {
      print("[RecipeService] Author info sync failed: $e");
    }
  }

  /// Removes a recipe from the user's default "Favorite" cookbook.
  /// Falls back to deleting from any cookbook containing the recipe if
  /// the Favorite cookbook is not found.
  Future<void> toggleFavorite(String userId, String recipeId) async {
    try {
      // Find the Favorite cookbook
      final snap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('cookbooks')
          .where('recipeIds', arrayContains: recipeId)
          .get();

      for (final doc in snap.docs) {
        final title = (doc.data()['title']?.toString() ?? '').toLowerCase();
        if (title == 'favorite') {
          await doc.reference.update({
            'recipeIds': FieldValue.arrayRemove([recipeId]),
          });
          print('[RecipeService] Removed $recipeId from Favorite cookbook');
          return;
        }
      }

      // Fallback: remove from whichever cookbook contains it
      if (snap.docs.isNotEmpty) {
        await snap.docs.first.reference.update({
          'recipeIds': FieldValue.arrayRemove([recipeId]),
        });
        print('[RecipeService] Removed $recipeId from first matching cookbook');
      }
    } catch (e) {
      print('[RecipeService] toggleFavorite failed: $e');
      rethrow;
    }
  }

  // --- Global Engagement Tracking for Trending ---

  /// Tracks a generic engagement event (view or like) for a recipe
  Future<void> _trackEngagement(String recipeId, String type) async {
    try {
      final ref = _firestore.collection('trending_events').doc();
      await ref.set({
        'recipeId': recipeId,
        'type': type, // 'view' or 'like'
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("[RecipeService] Failed to track engagement: $e");
    }
  }

  /// Calculates and fetches trending recipes based on recent engagement
  Future<List<Recipe>> getTrendingRecipes({int limit = 10, int days = 7, List<String>? allergies}) async {
    List<Recipe> results = [];
    final now = DateTime.now();
    
    // 1. Try to get trending from recent events with Recency Decay
    try {
      final cutoff = now.subtract(Duration(days: days));
      final eventsSnap = await _firestore
          .collection('trending_events')
          .where('timestamp', isGreaterThanOrEqualTo: cutoff)
          .get();

      if (eventsSnap.docs.isNotEmpty) {
        final Map<String, double> scores = {};
        for (final doc in eventsSnap.docs) {
          final data = doc.data();
          final recipeId = data['recipeId'] as String?;
          final type = data['type'] as String?;
          final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? cutoff;
          
          if (recipeId == null) continue;

          // Time decay: engagement from today is worth more than 6 days ago
          final hoursOld = now.difference(timestamp).inHours;
          final decayMultiplier = 1.0 / (1.0 + (hoursOld / 48.0)); // Soft decay every 2 days

          // weighted points: likes=10, views=2
          final basePoints = type == 'like' ? 10.0 : 2.0;
          final points = basePoints * decayMultiplier;
          
          scores[recipeId] = (scores[recipeId] ?? 0.0) + points;
        }

        final sortedIds = scores.keys.toList()
          ..sort((a, b) => scores[b]!.compareTo(scores[a]!));

        // Take more than limit to allow for allergy filtering
        final topIds = sortedIds.take(limit * 2).toList();
        results = await getRecipesByIds(topIds);
        
        if (allergies != null && allergies.isNotEmpty) {
           results = results.where((r) => _passesAllergyFilter(r, allergies)).toList();
        }
        results = results.take(limit).toList();
      }
    } catch (e) {
      print("[RecipeService] Trending events fetch failed: $e");
    }

    // 2. Fallback / Merge: Popular recipes from Firestore
    if (results.length < limit) {
      try {
        final popularSnap = await _firestore
            .collection('recipes')
            .orderBy('review_count', descending: true)
            .limit(limit * 4) // Fetch more to account for local filtering
            .get();
        
        var popularRecipes = popularSnap.docs
            .map((d) => Recipe.fromJson(d.data()))
            .where((r) => r.isPublic)
            .toList();
        
        if (allergies != null && allergies.isNotEmpty) {
          popularRecipes = popularRecipes.where((r) => _passesAllergyFilter(r, allergies)).toList();
        }

        // Merge without duplicates
        final existingIds = results.map((r) => r.id).toSet();
        for (var r in popularRecipes) {
          if (!existingIds.contains(r.id)) {
            results.add(r);
            if (results.length >= limit) break;
          }
        }
      } catch (e) {
        print("[RecipeService] Firestore popular fallback failed: $e");
      }
    }

    // 3. Final Fallback: Fetch "popular" recommendations from API
    if (results.isEmpty) {
      try {
        results = await _api.recommend(query: "popular", topK: limit, allergies: allergies ?? []);
      } catch (e) {
        print("[RecipeService] API popular fallback failed: $e");
      }
    }

    return results;
  }

  bool _passesAllergyFilter(Recipe r, List<String> userAllergies) {
    final rName = r.name.toLowerCase();
    final rTags = r.tags.map((e) => e.toLowerCase()).toSet();
    final rAllergens = (r.allergens).map((e) => e.toLowerCase()).toSet();
    final rIngredients = r.ingredients.map((e) => e.name.toLowerCase()).toList();

    final Map<String, List<String>> synonyms = {
      "dairy": ["milk", "cheese", "butter", "cream", "yogurt", "lactose", "whey", "casein", "ghee"],
      "tree nuts": ["almond", "walnut", "cashew", "pecan", "pistachio", "hazelnut", "brazil nut", "macadamia"],
      "shellfish": ["shrimp", "crab", "lobster", "mussel", "oyster", "scallop", "clam", "prawn"],
      "spicy": ["chili", "pepper", "jalapeno", "habanero", "cayenne", "sriracha", "hot sauce", "wasabi"],
      "gluten": ["wheat", "barley", "rye", "malt", "farro", "bulgur"],
      "eggs": ["egg", "yolk", "egg white", "albumin"],
    };

    for (final allergy in userAllergies) {
      final a = allergy.toLowerCase().trim();
      final searchTerms = [a, ...(synonyms[a] ?? [])];
      
      if (a == "gluten") {
        bool isGlutenFree = rName.contains("gluten-free") || 
                           rName.contains("gluten free") ||
                           rTags.contains("gluten-free") ||
                           rTags.contains("gluten free");
        if (isGlutenFree) continue;
      }

      for (final term in searchTerms) {
        if (rAllergens.contains(term)) return false;
        if (rTags.contains(term)) return false;
        if (rName.contains(term)) return false;
        for (final ing in rIngredients) {
          if (ing.contains(term)) return false;
        }
      }
    }
    return true;
  }

  Future<Recipe?> getTodaysPick({List<String>? allergies, String? selectedTag}) async {
    try {
      final now = DateTime.now();
      final day = now.weekday;
      
      // Theme based on the day of the week
      String themeTag;
      switch (day) {
        case 1: themeTag = "Dessert"; break;      // Monday
        case 2: themeTag = "Healthy"; break;      // Tuesday
        case 3: themeTag = "Asian"; break;        // Wednesday
        case 4: themeTag = "Quick"; break;        // Thursday
        case 5: themeTag = "Comfort Food"; break; // Friday
        case 6: themeTag = "Spicy"; break;        // Saturday
        case 7: themeTag = "Family"; break;       // Sunday
        default: themeTag = "Dinner";
      }

      List<Recipe> pool = [];

      // 1. Try to fetch from API using the exact theme tag and selected tag
      try {
        final queryStr = (selectedTag != null && selectedTag != "All") ? themeTag : "popular";
        final tagStr = (selectedTag != null && selectedTag != "All") ? selectedTag : themeTag;
        pool = await _api.recommend(
          query: queryStr, 
          tag: tagStr,
          topK: 20,
          allergies: allergies ?? [],
        );
        // Ensure API recipes have an image
        pool = pool.where((r) => r.imageUrl != null && r.imageUrl!.trim().isNotEmpty).toList();
      } catch (e) {
        print("[RecipeService] API theme fetch failed: $e");
      }

      // 2. Fallback to Firestore if API returns empty
      if (pool.isEmpty) {
        // Fetch recipes and filter locally since complex composite indexes might be missing
        final snap = await _firestore
            .collection('recipes')
            .where('is_public', isEqualTo: true)
            .orderBy('avg_rating', descending: true)
            .limit(50) 
            .get();

        var recipes = snap.docs.map((d) => Recipe.fromJson(d.data())).toList();
        
        // Filter allergens
        if (allergies != null && allergies.isNotEmpty) {
           recipes = recipes.where((r) => _passesAllergyFilter(r, allergies)).toList();
        }

        // Filter by the specific daily theme, the selected UI tag, and ensure it has an image!
        pool = recipes.where((r) {
          final hasImage = r.imageUrl != null && r.imageUrl!.trim().isNotEmpty;
          final matchesTheme = r.tags.any((t) => t.toLowerCase() == themeTag.toLowerCase()) || r.name.toLowerCase().contains(themeTag.toLowerCase());
          final matchesSelected = selectedTag == null || selectedTag == "All" || r.tags.any((t) => t.toLowerCase() == selectedTag.toLowerCase());
          return hasImage && matchesTheme && matchesSelected;
        }).toList();
      }

      // 3. Select the recipe from the pool
      if (pool.isNotEmpty) {
        // Sort by rating to be safe
        pool.sort((a, b) => b.avgRating.compareTo(a.avgRating));

        // Take the top 5 highest-rated recipes in this theme
        final topCandidates = pool.take(5).toList();

        // Cycle through the top 5 candidates based on the day of the year.
        // This ensures the pick changes EVERY day, even if the top pool is similar.
        final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
        final index = dayOfYear % topCandidates.length;

        return topCandidates[index];
      }

      // 4. Absolute fallback if no theme recipes exist at all: Just return a highly rated recipe
      final fallbackSnap = await _firestore
          .collection('recipes')
          .orderBy('avg_rating', descending: true)
          .limit(30) // Fetch more to account for local filtering
          .get();
          
      if (fallbackSnap.docs.isNotEmpty) {
         var recipes = fallbackSnap.docs
             .map((d) => Recipe.fromJson(d.data()))
             .where((r) => r.isPublic)
             .toList();
         if (allergies != null && allergies.isNotEmpty) {
           recipes = recipes.where((r) => _passesAllergyFilter(r, allergies)).toList();
         }
         // Ensure fallback recipe has an image
         recipes = recipes.where((r) => r.imageUrl != null && r.imageUrl!.trim().isNotEmpty).toList();
         if (recipes.isNotEmpty) {
            final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
            final index = dayOfYear % recipes.length;
            return recipes[index];
         }
      }

      return null;
    } catch (e) {
      print("[RecipeService] Error fetching Today's Pick: $e");
      return null;
    }
  }
}

