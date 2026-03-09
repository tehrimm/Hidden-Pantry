import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hidden_pantry_app/core/utils/recipe_matcher.dart';

class RecipeApiService {
  final String baseUrl;
  const RecipeApiService({required this.baseUrl});

  Future<List<String>> fetchTags({int limit = 15}) async {
    final uri = Uri.parse("$baseUrl/tags?limit=$limit");
    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return ["All", "Sushi", "Seafood", "Dessert"];

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final tags = (data["tags"] as List?)?.map((e) => e.toString()).toList() ?? [];
    if (tags.isEmpty) return ["All", "Sushi", "Seafood", "Dessert"];
    return tags;
  }

  Future<List<Recipe>> recommend({
    String? query,
    List<String> ingredients = const [],
    String? tag,
    List<String> allergies = const [],
    List<String> likedRecipeIds = const [],
    int? maxMinutes,
    double? minRating,
    int topK = 10,
  }) async {
    final uri = Uri.parse("$baseUrl/recommend");
    
    // Fallback: If no query/tag but we have likes, use likes to drive personalized results
    String? effectiveQuery = query;
    if (query == "popular" && likedRecipeIds.isNotEmpty) {
       effectiveQuery = "personalized";
    }

    final body = <String, dynamic>{
      "query": effectiveQuery,
      "ingredients": ingredients,
      "tag": tag == "All" ? null : tag,
      "allergies": allergies,
      "liked_recipe_ids": likedRecipeIds,
      "max_minutes": maxMinutes,
      "min_rating": minRating,
      "top_k": topK,
    };

    try {
      final res = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        throw Exception("Server returned ${res.statusCode}: ${res.body}");
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final results = (data["results"] as List?) ?? [];
      return results.map((e) => Recipe.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      print("Error in recommend: $e");
      rethrow;
    }
  }

  /// NEW: fetch ONE recipe by id (detail screen)
  /// Update the endpoint to match YOUR backend.
  /// Example endpoints:
  /// - GET /recipes/<id>
  /// - GET /recipe/<id>
  Future<Recipe> getRecipeById(String recipeId) async {
  final id = recipeId.trim();

  if (id.isEmpty) {
    throw Exception("Recipe id is empty. Check Recipe.fromJson mapping (id vs _id).");
  }

  // Try multiple endpoint patterns (because backends differ)
  final candidates = <Uri>[
    Uri.parse("$baseUrl/recipes/$id"),
    Uri.parse("$baseUrl/recipe/$id"),
    Uri.parse("$baseUrl/recipes?id=$id"),
    Uri.parse("$baseUrl/recipe?id=$id"),
  ];

  http.Response? lastRes;

  for (final uri in candidates) {
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      lastRes = res;

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);

        // Case 1: direct map -> recipe
        if (decoded is Map<String, dynamic>) {
          // Some APIs wrap it
          final maybeRecipe = decoded["recipe"] ?? decoded["data"] ?? decoded;
          if (maybeRecipe is Map<String, dynamic>) {
            return Recipe.fromJson(maybeRecipe);
          }
        }

        // If 200 but wrong shape
        throw Exception("Invalid recipe response shape from: ${uri.path}");
      }

      // If it's 404, try next candidate
      if (res.statusCode == 404) continue;

      // Other error codes: stop early (likely auth/server issue)
      throw Exception("Failed to load recipe (status ${res.statusCode}) from ${uri.path}");
    } catch (_) {
      // If request failed (network / json) try next candidate
      continue;
    }
  }

  final code = lastRes?.statusCode;
  throw Exception("Failed to load recipe (status ${code ?? "no response"}). Tried: /recipes/<id>, /recipe/<id>, /recipes?id, /recipe?id");
}


  /// NEW: author recipe count (if not included in author object)
  Future<int> countRecipesByAuthor(String authorId) async {
    final uri = Uri.parse("$baseUrl/authors/$authorId/recipe_count");
    final res = await http.get(uri).timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) return 0;

    final data = jsonDecode(res.body);
    if (data is Map<String, dynamic>) {
      final v = data["count"];
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? 0;
    }
    return 0;
  }

  /// NEW: get author statistics (followers, rating, etc.)
  Future<Map<String, dynamic>> getAuthorStats(String authorId) async {
    final id = authorId.trim();
    if (id.isEmpty) return {};

    final uri = Uri.parse("$baseUrl/authors/$id/stats");
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return {};
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      print("Error in getAuthorStats: $e");
      return {};
    }
  }

  /// NEW: fetch recipes by author id
  Future<List<Recipe>> fetchRecipesByAuthor(String authorId, {int limit = 10}) async {
    final id = authorId.trim();
    if (id.isEmpty) return [];

    final uri = Uri.parse("$baseUrl/authors/$id/recipes?limit=$limit");
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final results = (data["results"] as List?) ?? [];
      return results.map((e) => Recipe.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      print("Error in fetchRecipesByAuthor: $e");
      return [];
    }
  }

  /// Search recipes by query (searches name and tags)
  Future<List<Recipe>> searchRecipes(
    String query, {
    int limit = 50,
    List<String>? ingredients,
    int? maxMinutes,
    List<String>? tags,
    List<String>? allergies,
  }) async {
    Map<String, num> userTagWeights = {};
    Set<String> recentViewed = {};
    Set<String> followedAuthors = {};
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final snap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final data = snap.data();
        if (data != null && data['tagWeights'] is Map) {
          final tw = data['tagWeights'] as Map;
          userTagWeights = tw.map((k, v) => MapEntry(k.toString().toLowerCase(), num.tryParse(v.toString()) ?? 0));
        }
        try {
          final vs = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('views')
              .orderBy('lastViewed', descending: true)
              .limit(200)
              .get();
          recentViewed = vs.docs.map((d) => d.id).toSet();
        } catch (_) {}
        try {
          final fs = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('following')
              .get();
          followedAuthors = fs.docs.map((d) => d.id).toSet();
        } catch (_) {}
      }
    } catch (_) {}
    // Allow search if we have query, ingredients, or tags
    final hasQuery = query.trim().isNotEmpty;
    final hasIngredients = ingredients != null && ingredients.isNotEmpty;
    final hasTags = tags != null && tags.isNotEmpty;
    
    print('DEBUG API searchRecipes: query=\"$query\", hasQuery=$hasQuery, hasIngredients=$hasIngredients (${ingredients?.length ?? 0}), hasTags=$hasTags');
    
    if (!hasQuery && !hasIngredients && !hasTags) {
      print('DEBUG API: Returning empty - nothing to search for');
      return []; // Nothing to search for
    }
    
    // Backend requires a non-empty query. If no query, use ingredients or default to "recipe"
    // Using ingredients as the query helps the semantic search find better candidates.
    final effectiveQuery = hasQuery ? query : (hasIngredients ? ingredients.join(" ") : "recipe");
    print('DEBUG API: Using effectiveQuery="$effectiveQuery"');
    
    final uri = Uri.parse("$baseUrl/recommend");
    // Fetch MORE results (top_k) for ingredient searches to allow effective local filtering
    final topK = (hasIngredients || (allergies != null && allergies.isNotEmpty)) ? 5000 : (limit > 50 ? limit : 50);
    
    final body = <String, dynamic>{
      "query": effectiveQuery,
      "ingredients": ingredients ?? [],
      "max_minutes": maxMinutes,
      "top_k": topK, 
      "allergies": allergies ?? [], // Pass to backend if it supports it
    };

    try {
      final res = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        throw Exception("Server returned ${res.statusCode}");
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final resultsData = (data["results"] as List?) ?? [];
      var allRecipes = resultsData.map((e) => Recipe.fromJson(e as Map<String, dynamic>)).toList();
      
      // Local Filtering
      if (maxMinutes != null) {
        allRecipes = allRecipes.where((r) => r.minutes > 0 && r.minutes <= maxMinutes).toList();
      }

      // Allergen Filtering (Local)
      if (allergies != null && allergies.isNotEmpty) {
        allRecipes = allRecipes.where((r) => RecipeMatcher.isSafe(r, allergies)).toList();
      }

      // Note: We no longer perform strict tag filtering here.
      // Instead, we will use tags in the ranking logic below to prioritize "best matches".

      // Filter by ingredients if provided — strict AND with flexible fallback
      if (ingredients != null && ingredients.isNotEmpty) {
        print('DEBUG API: Filtering ${allRecipes.length} recipes by ${ingredients.length} ingredients');
        
        // First try strict AND: recipe must contain ALL selected ingredients
        final strictResults = allRecipes.where((r) {
          final recipeIngredientNames = r.ingredients.map((i) => i.name.toLowerCase()).toList();
          return ingredients.every((selectedIng) {
            final selectedLower = selectedIng.toLowerCase();
            return recipeIngredientNames.any((rIng) =>
              rIng.contains(selectedLower) || selectedLower.contains(rIng)
            );
          });
        }).toList();
        
        if (strictResults.isNotEmpty) {
          print('DEBUG API: Strict AND matched ${strictResults.length} recipes');
          allRecipes = strictResults;
        } else {
          // Fallback to flexible OR: at least 1 ingredient must match
          print('DEBUG API: Strict AND found 0, falling back to flexible OR');
          allRecipes = allRecipes.where((r) {
            final recipeIngredientNames = r.ingredients.map((i) => i.name.toLowerCase()).toList();
            return ingredients.any((selectedIng) {
              final selectedLower = selectedIng.toLowerCase();
              return recipeIngredientNames.any((rIng) =>
                rIng.contains(selectedLower) || selectedLower.contains(rIng)
              );
            });
          }).toList();
          print('DEBUG API: Flexible OR matched ${allRecipes.length} recipes');
        }
      }

      // Sorting & Ranking
      final q = query.toLowerCase().trim();
      final scoredRecipes = <MapEntry<Recipe, double>>[];

      for (final r in allRecipes) {
        double score = 1.0; 
        
        // Boost based on number of matching ingredients
        if (hasIngredients) {
          final recipeIngs = r.ingredients.map((i) => i.name.toLowerCase()).toList();
          int matchCount = 0;
          for (final selected in ingredients) {
            final lower = selected.toLowerCase();
            if (recipeIngs.any((ri) => ri.contains(lower) || lower.contains(ri))) {
              matchCount++;
            }
          }
          score += matchCount * 100; // Large boost for ingredient matches
          
          // Bonus: prefer recipes with FEWER total ingredients (closer to exact pantry match)
          if (r.ingredients.isNotEmpty) {
            score += (1.0 / r.ingredients.length) * 50;
          }
        }

        // Boost based on number of matching tags (Flexible OR / Best Match)
        if (tags != null && tags.isNotEmpty) {
          final recipeTags = r.tags.map((t) => t.toLowerCase()).toList();
          int tagMatchCount = 0;
          for (final selected in tags) {
            final lower = selected.toLowerCase();
            if (recipeTags.contains(lower)) {
              tagMatchCount++;
            }
          }
          score += tagMatchCount * 50; // Weight for tag matches
        }

        // User preference boost based on tagWeights
        if (userTagWeights.isNotEmpty) {
          double pref = 0;
          for (final t in r.tags) {
            pref += (userTagWeights[t.toLowerCase()] ?? 0).toDouble();
          }
          score += pref; // gentle nudge, name/ingredients boosts still dominate
        }
        if (r.authorId.isNotEmpty && followedAuthors.contains(r.authorId)) {
          score += 200;
        }
        if (recentViewed.contains(r.id)) {
          score -= 300;
        }

        if (q.isNotEmpty) {
           // 1. Name Match
          final rName = r.name.toLowerCase();
          if (rName == q) {
            score += 500; 
          } else if (rName.startsWith(q)) {
            score += 200; 
          } else if (rName.contains(q)) {
            score += 100;
          }
          
          // 2. Ingredients Match (with query text)
          final hasIng = r.ingredients.any((i) => i.name.toLowerCase().contains(q));
          if (hasIng) score += 40;
          
          // 3. Tags Match (Query)
          final hasTag = r.tags.any((t) => t.toLowerCase().contains(q));
          if (hasTag) score += 20;

          // 4. Author Name Match
          final hasAuthor = (r.authorName ?? "").toLowerCase().contains(q);
          if (hasAuthor) score += 30;
        } else {
          // If no query, use rating as secondary sort
          score += r.avgRating * 2;
        }

        scoredRecipes.add(MapEntry(r, score));
      }

      scoredRecipes.sort((a, b) => b.value.compareTo(a.value));
      
      // Filter out recipes that match NO tags if tags were specified
      // but only if NO search query was provided. 
      // This keeps the result pool clean for "pure" tag/ingredient searches.
      var finalResults = scoredRecipes;
      if (tags != null && tags.isNotEmpty && q.isEmpty) {
         // Keep only those that matched at least one tag
         // (Ingredients are already strictly filtered above)
         finalResults = finalResults.where((e) {
            final r = e.key;
            return r.tags.any((rt) => tags.any((st) => st.toLowerCase() == rt.toLowerCase()));
         }).toList();
      }

      return finalResults
          .map((e) => e.key)
          .take(limit)
          .toList();
    } catch (e) {
      print("Error in searchRecipes: $e");
      rethrow;
    }
  }

  /// Fetch following feed
  Future<List<Recipe>> fetchFollowingFeed(List<String> authorIds, {int limit = 20}) async {
    if (authorIds.isEmpty) return [];
    
    final uri = Uri.parse("$baseUrl/recipes/feed");
    final res = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "author_ids": authorIds,
        "limit": limit,
      }),
    ).timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) return [];

    final data = jsonDecode(res.body);
    final List list = data["results"] ?? [];
    return list.map((json) => Recipe.fromJson(json)).toList();
  }
}



