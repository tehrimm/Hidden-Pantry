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
      final user = _auth.currentUser;

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
        
        // 3. Fetch missing from API
        for (var id in missingIds) {
          try {
            final r = await _api.getRecipeById(id);
            results.add(r);
          } catch (e) {
            print("[RecipeService] API fallback failed for $id: $e");
            if (partialDocs.containsKey(id)) {
               final data = partialDocs[id]!;
               data['name'] = "Recipe Unavailable";
               data['minutes'] = 0;
               results.add(Recipe.fromJson(data));
            } else {
               results.add(Recipe(
                 id: id, 
                 name: "Recipe Unavailable", 
                 minutes: 0, 
                 avgRating: 0.0, 
                 authorName: "System",
                 imageUrl: null
               ));
            }
          }
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
    
    final searchKey = query.toLowerCase();
    
    try {
      // 1. Initial query by name if provided
      Query<Map<String, dynamic>> baseQuery = _firestore.collection('recipes');
      
      if (searchKey.isNotEmpty) {
        baseQuery = baseQuery
            .where('name_search', isGreaterThanOrEqualTo: searchKey)
            .where('name_search', isLessThanOrEqualTo: '$searchKey\uf8ff');
      }

      // 2. Filter out nutritionist recipes
      // Note: We do this locally to avoid hiding recipes where the field is missing
      final snap = await baseQuery.limit(limit * 5).get(); // Fetch more for local filtering
          
      var results = snap.docs
          .map((doc) => Recipe.fromJson(doc.data()))
          .where((r) {
            // Only show recipes that are explicitly marked as public
            return r.isPublic;
          })
          .toList();

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
          return ingredients.every((si) => rIngs.any((ri) => ri.contains(si.toLowerCase())));
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
}

