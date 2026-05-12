import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hidden_pantry_app/core/utils/recipe_matcher.dart';

class RecipeApiService {
  final String baseUrl;
  const RecipeApiService({required this.baseUrl});

  // --- Memory Cache ---
  static final Map<String, dynamic> _cache = {};
  static final Map<String, DateTime> _cacheTime = {};
  static const _cacheDuration = Duration(minutes: 10);

  bool _isCacheValid(String key) {
    if (!_cache.containsKey(key)) return false;
    final time = _cacheTime[key];
    if (time == null) return false;
    return DateTime.now().difference(time) < _cacheDuration;
  }

  void _setCache(String key, dynamic value) {
    _cache[key] = value;
    _cacheTime[key] = DateTime.now();
  }

  Future<List<String>> fetchTags({int limit = 15}) async {
    final cacheKey = "tags_$limit";
    if (_isCacheValid(cacheKey)) return _cache[cacheKey] as List<String>;

    final uri = Uri.parse("$baseUrl/tags?limit=$limit");
    final res = await http.get(uri).timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) return ["All", "Sushi", "Seafood", "Dessert"];

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final tags = (data["tags"] as List?)?.map((e) => e.toString()).toList() ?? [];
    if (tags.isEmpty) return ["All", "Sushi", "Seafood", "Dessert"];
    
    _setCache(cacheKey, tags);
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

    final cacheKey = "rec_${jsonEncode(body)}";
    if (_isCacheValid(cacheKey)) return _cache[cacheKey] as List<Recipe>;

    try {
      final res = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode != 200) {
        throw Exception("Server returned ${res.statusCode}: ${res.body}");
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final results = (data["results"] as List?) ?? [];
      final recipes = results.map((e) => Recipe.fromJson(e as Map<String, dynamic>)).toList();
      
      _setCache(cacheKey, recipes);
      return recipes;
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
      throw Exception("Recipe id is empty.");
    }

    // Candidate endpoints
    final candidates = <Uri>[
      Uri.parse("$baseUrl/recipes/$id"),
      Uri.parse("$baseUrl/recipe/$id"),
      Uri.parse("$baseUrl/recipes?id=$id"),
      Uri.parse("$baseUrl/recipe?id=$id"),
    ];

    try {
      // Try all candidates in parallel to avoid sequential timeout delays
      final responses = await Future.wait(
        candidates.map((uri) => http.get(uri).timeout(const Duration(seconds: 8)).catchError((e) {
          return http.Response("Timeout or Error", 408);
        })),
      );

      for (var i = 0; i < responses.length; i++) {
        final res = responses[i];
        if (res.statusCode == 200) {
          final decoded = jsonDecode(res.body);
          if (decoded is Map<String, dynamic>) {
            final maybeRecipe = decoded["recipe"] ?? decoded["data"] ?? decoded;
            if (maybeRecipe is Map<String, dynamic>) {
              return Recipe.fromJson(maybeRecipe);
            }
          }
        }
      }
      
      throw Exception("Recipe not found after trying multiple endpoints.");
    } catch (e) {
      print("[RecipeApiService] getRecipeById failed: $e");
      rethrow;
    }
  }


  /// NEW: author recipe count (if not included in author object)
  Future<int> countRecipesByAuthor(String authorId) async {
    final uri = Uri.parse("$baseUrl/authors/$authorId/recipe_count");
    final res = await http.get(uri).timeout(const Duration(seconds: 30));

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
      final res = await http.get(uri).timeout(const Duration(seconds: 30));
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
      final res = await http.get(uri).timeout(const Duration(seconds: 30));
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
    // Fetch MORE results for ingredient/allergy filtering, but cap to avoid timeouts
    final topK = (hasIngredients || (allergies != null && allergies.isNotEmpty)) ? 200 : (limit > 50 ? limit : 50);
    
    final body = <String, dynamic>{
      "query": effectiveQuery,
      "ingredients": ingredients ?? [],
      "max_minutes": maxMinutes,
      "top_k": topK, 
      "allergies": allergies ?? [], // Pass to backend if it supports it
    };

    Map<String, num> userTagWeights = {};
    Set<String> recentViewed = {};
    Set<String> followedAuthors = {};
    var allRecipes = <Recipe>[];
    
    final futures = <Future>[];

    // Backend Recipe Search Fetch
    futures.add(
      http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 45)).then((res) {
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final resultsData = (data["results"] as List?) ?? [];
          allRecipes = resultsData.map((e) => Recipe.fromJson(e as Map<String, dynamic>)).toList();
        } else {
          print("searchRecipes Server returned ${res.statusCode}");
        }
      }).catchError((e) {
        print("[API] HTTP searchRecipes failed: $e");
        return [];
      })
    );

    // Personalization fetch
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        futures.add(
          FirebaseFirestore.instance.collection('users').doc(user.uid).get().then((snap) {
            final data = snap.data();
            if (data != null && data['tagWeights'] is Map) {
              final tw = data['tagWeights'] as Map;
              userTagWeights = tw.map((k, v) => MapEntry(k.toString().toLowerCase(), num.tryParse(v.toString()) ?? 0));
            }
          }).catchError((_) {})
        );
        futures.add(
          FirebaseFirestore.instance.collection('users').doc(user.uid).collection('views')
              .orderBy('lastViewed', descending: true).limit(200).get().then((vs) {
            recentViewed = vs.docs.map((d) => d.id).toSet();
          }).catchError((_) {})
        );
        futures.add(
          FirebaseFirestore.instance.collection('users').doc(user.uid).collection('following').get().then((fs) {
            followedAuthors = fs.docs.map((d) => d.id).toSet();
          }).catchError((_) {})
        );
      }
    } catch (_) {}

    await Future.wait(futures);

    try {
      
      // Local Filtering
      if (maxMinutes != null) {
        allRecipes = allRecipes.where((r) => r.minutes > 0 && r.minutes <= maxMinutes).toList();
      }

      // NOTE: Allergen filtering is handled by the backend (allergies passed in request body).
      // Local re-filtering with RecipeMatcher is intentionally removed — it uses over-broad
      // synonym matching (e.g. "wheat" blocks anything with "flour" or "bread") which
      // eliminates nearly all results. Trust the backend's filtering instead.

      // Note: We no longer perform strict tag filtering here.
      // Instead, we will use tags in the ranking logic below to prioritize "best matches".

      // Filter by ingredients if provided — strict AND with flexible fallback
      if (ingredients != null && ingredients.isNotEmpty) {
        print('DEBUG API: Filtering ${allRecipes.length} recipes by ${ingredients.length} ingredients');

        // Smart ingredient match:
        // - "almond milk" (multi-word) only matches if recipe ingredient CONTAINS the full term.
        //   Prevents "almond milk".contains("milk") = true causing false positives.
        // - "chicken" (single-word) also checks reverse so "chicken breast" in recipe matches.
        bool _matchIngredient(String selectedIng, String rIng) {
          final s = selectedIng.toLowerCase().trim();
          final r = rIng.toLowerCase().trim();
          if (r.contains(s)) return true; // recipe has "unsweetened almond milk" → matches "almond milk"
          // Only allow reverse for single-word selectors (avoid "almond milk" matching "milk")
          if (!s.contains(' ') && s.contains(r)) return true;
          return false;
        }

        // Strict AND ONLY: recipe must contain ALL selected ingredients
        allRecipes = allRecipes.where((r) {
          final recipeIngredientNames = r.ingredients.map((i) => i.name.toLowerCase()).toList();
          return ingredients.every((selectedIng) =>
            recipeIngredientNames.any((rIng) => _matchIngredient(selectedIng, rIng))
          );
        }).toList();
        print('DEBUG API: Strict AND matched ${allRecipes.length} recipes');
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
      print("[API] searchRecipes failed: $e");
      return []; // Return empty instead of rethrowing, so UI shows empty state not crash
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
    ).timeout(const Duration(seconds: 30));

    if (res.statusCode != 200) return [];

    final data = jsonDecode(res.body);
    final List list = data["results"] ?? [];
    return list.map((json) => Recipe.fromJson(json)).toList();
  }
}



