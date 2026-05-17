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

    final uri = Uri.parse("$baseUrl/recipes/$id");

    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          final maybeRecipe = decoded["recipe"] ?? decoded["data"] ?? decoded;
          if (maybeRecipe is Map<String, dynamic>) {
            return Recipe.fromJson(maybeRecipe);
          }
        }
      }
      
      throw Exception("Recipe not found or invalid format.");
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
    // Fetch a large pool (300) from the backend semantic search. 
    // Semantic embeddings often bury exact keyword matches behind "similar" junk.
    // We need a deep pool so our local strict text filter and +500 exact-match
    // scoring logic has the actual recipes to promote to the top.
    final topK = 300; 
    
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
          FirebaseFirestore.instance.collection('users').doc(user.uid).get().timeout(const Duration(seconds: 3)).then((snap) {
            final data = snap.data();
            if (data != null && data['tagWeights'] is Map) {
              final tw = data['tagWeights'] as Map;
              userTagWeights = tw.map((k, v) => MapEntry(k.toString().toLowerCase(), num.tryParse(v.toString()) ?? 0));
            }
          }).catchError((_) {})
        );
        futures.add(
          FirebaseFirestore.instance.collection('users').doc(user.uid).collection('views')
              .orderBy('lastViewed', descending: true).limit(200).get().timeout(const Duration(seconds: 3)).then((vs) {
            recentViewed = vs.docs.map((d) => d.id).toSet();
          }).catchError((_) {})
        );
        futures.add(
          FirebaseFirestore.instance.collection('users').doc(user.uid).collection('following').get().timeout(const Duration(seconds: 3)).then((fs) {
            followedAuthors = fs.docs.map((d) => d.id).toSet();
          }).catchError((_) {})
        );
      }
    } catch (_) {}

    print("DEBUG API: Waiting for all futures (Backend + Firestore Personalization)...");
    await Future.wait(futures);
    print("DEBUG API: Futures complete. API returned ${allRecipes.length} recipes before local filtering.");

    try {
      
      // Local Filtering
      if (maxMinutes != null) {
        allRecipes = allRecipes.where((r) => r.minutes > 0 && r.minutes <= maxMinutes).toList();
      }

      // Filter by ingredients if provided — strict AND with flexible fallback
      if (ingredients != null && ingredients.isNotEmpty) {
        print('DEBUG API: Filtering ${allRecipes.length} recipes by ${ingredients.length} ingredients');

        bool _matchIngredient(String selectedIng, String rIng) {
          final s = selectedIng.toLowerCase().trim();
          final r = rIng.toLowerCase().trim();
          if (r.contains(s)) return true; 
          if (!s.contains(' ') && s.contains(r)) return true;
          return false;
        }

        allRecipes = allRecipes.where((r) {
          final recipeIngredientNames = r.ingredients.map((i) => i.name.toLowerCase()).toList();
          final rName = r.name.toLowerCase();
          
          return ingredients.every((selectedIng) {
            // Check ingredients first
            bool hasIng = recipeIngredientNames.any((rIng) => _matchIngredient(selectedIng, rIng));
            // If not found in ingredients, check if it's literally in the recipe title
            if (!hasIng) {
              final s = selectedIng.toLowerCase().trim();
              if (rName.contains(s)) hasIng = true;
            }
            return hasIng;
          });
        }).toList();
        print('DEBUG API: Strict AND matched ${allRecipes.length} recipes');
      }

      // Sorting & Ranking
      final q = query.toLowerCase().trim();
      final scoredRecipes = <MapEntry<Recipe, double>>[];
      
      print("DEBUG API: Starting scoring loop for ${allRecipes.length} recipes with query='$q'");

      for (final r in allRecipes) {
        double score = 1.0; 
        
        if (hasIngredients) {
          final recipeIngs = r.ingredients.map((i) => i.name.toLowerCase()).toList();
          int matchCount = 0;
          for (final selected in ingredients) {
            final lower = selected.toLowerCase();
            if (recipeIngs.any((ri) => ri.contains(lower) || lower.contains(ri))) {
              matchCount++;
            }
          }
          score += matchCount * 100; 
          if (r.ingredients.isNotEmpty) score += (1.0 / r.ingredients.length) * 50;
        }

        if (tags != null && tags.isNotEmpty) {
          final recipeTags = r.tags.map((t) => t.toLowerCase()).toList();
          int tagMatchCount = 0;
          for (final selected in tags) {
            if (recipeTags.contains(selected.toLowerCase())) tagMatchCount++;
          }
          score += tagMatchCount * 50;
        }

        if (userTagWeights.isNotEmpty) {
          double pref = 0;
          for (final t in r.tags) {
            pref += (userTagWeights[t.toLowerCase()] ?? 0).toDouble();
          }
          score += pref; 
        }
        if (r.authorId.isNotEmpty && followedAuthors.contains(r.authorId)) score += 200;
        if (recentViewed.contains(r.id)) score -= 300;

        if (q.isNotEmpty) {
          final rName = r.name.toLowerCase();
          bool hasNameMatch = false;
          if (rName == q) {
            score += 500; 
            hasNameMatch = true;
          } else if (rName.startsWith(q)) {
            score += 200; 
            hasNameMatch = true;
          } else if (rName.contains(q)) {
            score += 100;
            hasNameMatch = true;
          }
          
          final hasIng = r.ingredients.any((i) => i.name.toLowerCase().contains(q));
          if (hasIng) score += 40;
          
          final hasTag = r.tags.any((t) => t.toLowerCase().contains(q));
          if (hasTag) score += 20;

          final hasAuthor = (r.authorName ?? "").toLowerCase().contains(q);
          if (hasAuthor) score += 30;

          if (!hasNameMatch && !hasIng && !hasTag && !hasAuthor) {
            print("DEBUG API: Dropping '${r.name}' because it does not contain the word '$q'");
            continue;
          }
        } else {
          score += r.avgRating * 2;
        }

        scoredRecipes.add(MapEntry(r, score));
      }

      scoredRecipes.sort((a, b) => b.value.compareTo(a.value));
      print("DEBUG API: Scored list contains ${scoredRecipes.length} recipes after STRICT filter");
      
      var finalResults = scoredRecipes;
      if (tags != null && tags.isNotEmpty && q.isEmpty) {
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



