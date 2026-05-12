import 'dart:developer';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_api_service.dart';
import 'package:hidden_pantry_app/core/widgets/skeletons.dart';
import 'package:hidden_pantry_app/core/widgets/home_bottom_nav.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_service.dart';
import 'package:hidden_pantry_app/core/services/moderation_service.dart';

import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';

import 'package:hidden_pantry_app/features/recipes/screens/recipe_details.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';

import 'package:hidden_pantry_app/features/recipes/screens/category_screen.dart';
import 'package:hidden_pantry_app/features/user/screens/user_profile.dart';
import 'package:hidden_pantry_app/features/recipes/screens/search/search.dart';
import 'package:hidden_pantry_app/core/constants/api_constants.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/features/recipes/screens/saved_recipes.dart';
import 'package:hidden_pantry_app/features/recipes/upload/upload_recipe_step1.dart';
import 'package:hidden_pantry_app/features/nutritionist/screens/discovery.dart';
import 'package:hidden_pantry_app/core/services/view_mode_service.dart';
import 'package:hidden_pantry_app/features/nutritionist/screens/nutritionist_dashboard.dart';
import 'package:hidden_pantry_app/features/nutritionist/screens/nutritionist_settings.dart';
import 'package:hidden_pantry_app/features/user/services/follow_service.dart';
import 'package:hidden_pantry_app/features/recipes/widgets/recipe_card.dart';
import 'package:hidden_pantry_app/features/user/screens/notifications_screen.dart';
import 'package:hidden_pantry_app/core/services/notification_service.dart';
import 'package:hidden_pantry_app/features/user/models/notification_model.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';

class HomeScreen extends StatefulWidget {
  final bool inShell;
  final RecipeApiService? apiService;
  final FirebaseAuth? auth;
  const HomeScreen({super.key, this.inShell = false, this.apiService, this.auth});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final RecipeService _recipeService = RecipeService();
  late final RecipeApiService api;
  Set<String> _blockedUserIds = {};
  late final FirebaseAuth _auth;

  final Color bg = const Color(0xFFFFF3EB);
  final Color chipBg = const Color(0xFFF9E3D5);
  final Color purple = const Color(0xFF462F4D);
  final Color orange = const Color(0xFFEF8A54);

  List<String> tags = const [];
  String selectedTag = "All";

  bool loading = true;
  String? loadError;

  List<Recipe> recommendations = const [];
  List<Recipe> weekly = const [];
  List<Recipe> followingFeed = const [];

  final FollowService _followService = FollowService();

  // Updated to be dynamic
  List<String> userAllergies = [];
  String? photoUrl;
  Map<String, num> _tagWeights = {};
  Set<String> _recentViewed = {};
  Set<String> _followedAuthorIds = {};

  int bottomIndex = 0; // 0 home, 1 search, 2 plus, 3 bookmark, 4 nutritionist
  bool isNutritionistInUserView = false;

  final ScrollController _tagScrollController = ScrollController();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isSpeechAvailable = false;
  bool _isListening = false;

  @override
  void dispose() {
    _tagScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _auth = widget.auth ?? FirebaseAuth.instance;
    api = widget.apiService ?? const RecipeApiService(baseUrl: ApiConstants.baseUrl);
    _checkNutritionistStatus();
    _loadHome();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      _isSpeechAvailable = await _speech.initialize(
        onStatus: (status) => print("[Speech] Status: $status"),
        onError: (errorNotification) => print("[Speech] Error: $errorNotification"),
      );
      if (mounted) setState(() {});
    } catch (e) {
      print("[Speech] Init error: $e");
    }
  }

  void _toggleListening() async {
    // Check permission first
    try {
      var status = await Permission.microphone.status;
      if (status.isDenied) {
        status = await Permission.microphone.request();
        if (!status.isGranted) {
          if (mounted) Toaster.show(context, "Microphone permission is required for voice search.", isError: true);
          return;
        }
        // If just granted, re-init speech
        await _initSpeech();
      }
    } catch (e) {
      print("[Speech] Permission check error: $e");
      if (mounted) Toaster.show(context, "Could not access microphone. Please restart the app.", isError: true);
      return;
    }

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      if (_isSpeechAvailable) {
        setState(() => _isListening = true);
        await _speech.listen(
          onResult: (result) {
            if (result.finalResult) {
              setState(() => _isListening = false);
              if (result.recognizedWords.isNotEmpty) {
                // Navigate to search with the words
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SearchScreen(initialQuery: result.recognizedWords)),
                );
              }
            }
          },
        );
      } else {
        Toaster.show(context, "Voice search is not ready. Please try again in a moment.", isError: true);
        _initSpeech();
      }
    }
  }

  Future<void> _checkNutritionistStatus() async {
    final isNutr = await ViewModeService().isNutritionist();
    if (mounted) {
      setState(() => isNutritionistInUserView = isNutr);
    }
  }

  Future<void> _loadHome() async {
    if (mounted) {
      setState(() {
        // Only show loading if we don't have data yet
        if (recommendations.isEmpty && weekly.isEmpty) {
          loading = true;
        }
        loadError = null;
      });
    }

    try {
      // 1. Fetch user data and tags concurrently
      List<String> fetchedTags = [];
      List<String> likedIds = [];
      List<String> followedIds = [];
      
      final user = _auth.currentUser;
      final initialFutures = <Future>[
        api.fetchTags(limit: 50).then((v) => fetchedTags = v).catchError((_) => <String>[]),
      ];

      if (user != null) {
        initialFutures.add(
          FirebaseFirestore.instance.collection("users").doc(user.uid).get().then((doc) {
            final data = doc.data();
            if (data != null) {
              final list = data['allergies'];
              if (list is List) {
                userAllergies = list.map((e) => e.toString()).toList();
              }
              photoUrl = (data['photoUrl'] as String?)?.trim() ?? user.photoURL;
              final tw = data['tagWeights'];
              if (tw is Map) {
                _tagWeights = tw.map((k, v) => MapEntry(k.toString().toLowerCase(), num.tryParse(v.toString()) ?? 0));
              }
            }
          }).catchError((_) {})
        );

        initialFutures.add(
          ModerationService().getBlockedUsers().then((v) {
            _blockedUserIds = v.toSet();
          }).catchError((_) {})
        );

        initialFutures.add(
          _recipeService.getLikedRecipeIds(user.uid).then((v) => likedIds = v).catchError((_) => <String>[])
        );

        initialFutures.add(
          FirebaseFirestore.instance.collection('users').doc(user.uid).collection('views')
              .orderBy('lastViewed', descending: true).limit(20).get().then((snap) {
            _recentViewed = snap.docs.map((d) => d.id).toSet();
          }).catchError((_) {})
        );

        initialFutures.add(
          _followService.getFollowedAuthorIds().then((v) {
            followedIds = v;
            _followedAuthorIds = v.toSet();
          }).catchError((_) {})
        );
      }

      await Future.wait(initialFutures);
      final fixedTags = _fixTags(fetchedTags);

      // 2. Fetch recipe recommendations concurrently
      List<Recipe> rec = [];
      List<Recipe> week = [];
      List<Recipe> feed = [];

      final feedFallback = () async {
        try {
          final chunks = <List<String>>[];
          for (var i = 0; i < followedIds.length; i += 10) {
            chunks.add(followedIds.sublist(i, i + 10 < followedIds.length ? i + 10 : followedIds.length));
          }
          final allDocs = <Recipe>[];
          for (final chunk in chunks) {
            final snap = await FirebaseFirestore.instance.collection('recipes')
                .where('author_id', whereIn: chunk)
                .where('is_public', isEqualTo: true).limit(30).get();
            final fetched = snap.docs.map((d) => Recipe.fromJson(d.data()));
            allDocs.addAll(fetched.where((r) => !_blockedUserIds.contains(r.authorId)));
          }
          final byId = <String, Recipe>{};
          for (final r in allDocs) if (r.id.isNotEmpty) byId[r.id] = r;
          return byId.values.toList();
        } catch (e) {
          log("Home: Following Feed Firestore fallback error: $e");
          return <Recipe>[];
        }
      };

      final recipeFutures = <Future>[
        api.recommend(
          query: "popular", tag: selectedTag, allergies: userAllergies,
          likedRecipeIds: likedIds, topK: 50, minRating: 0.0,
        ).then((v) => rec = v).catchError((_) => <Recipe>[]),

        RecipeService().getTrendingRecipes(limit: 50).then((v) => week = v).catchError((_) => <Recipe>[]),
      ];

      if (followedIds.isNotEmpty) {
        recipeFutures.add(
          api.fetchFollowingFeed(followedIds).then((res) async {
            if (res.isNotEmpty) {
              feed = res;
            } else {
              feed = await feedFallback();
            }
          }).catchError((_) async {
            feed = await feedFallback();
          })
        );
      }

      await Future.wait(recipeFutures);


      if (!mounted) return;
      setState(() {
        tags = fixedTags;
        recommendations = _rerankByPreferences(rec);
        weekly = _rerankByPreferences(week);
        followingFeed = feed;
        loading = false;
      });

      log("Home loaded: tags=${fixedTags.length}, rec=${rec.length}, week=${week.length}, allergies=$userAllergies");
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        loadError = e.toString();
        tags = _fixTags(const []);
        recommendations = const [];
        weekly = const [];
        // Keep existing user data on error if possible
      });
      log("Home error: $e");
    }
  }

  String _beautify(String t) {
    if (t.toLowerCase() == "all") return "All";
    final clean = t.replaceAll(RegExp(r'[_\-]'), ' ').trim();
    if (clean.isEmpty) return t;
    return clean.split(' ').map((word) {
      if (word.isEmpty) return "";
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  List<String> _fixTags(List<String> incoming) {
    final preferred = <String>[
      "All",
      "Breakfast",
      "Lunch",
      "Dinner",
      "Pakistani",
      "Asian",
      "Dessert",
      "Snack",
      "Soup",
      "Salad",
      "Chicken",
      "Seafood",
      "Rice",
      "Beverage",
      "Baked",
      "Spicy",
    ];

    // 1. Combine preferred with incoming (raw)
    final combined = [...preferred, ...incoming];

    // 2. Filter out generic "time" or "quantity" tags
    final filtered = combined.where((t) {
      final low = t.toLowerCase();
      // Keep preferred tags even if they look like common words
      if (preferred.any((p) => p.toLowerCase() == low)) return true;
      return !low.contains("minutes") && 
             !low.contains("step") && 
             !low.contains("less than") &&
             !low.contains("servings");
    }).toList();

    // 3. Remove duplicates (case-insensitive) but keep original casing for API
    final seen = <String>{};
    final result = <String>[];
    for (var tag in filtered) {
       final normalized = tag.toLowerCase().trim();
       if (normalized.isNotEmpty && seen.add(normalized)) {
         result.add(tag);
       }
    }

    return result;
  }

  List<Recipe> _rerankByPreferences(List<Recipe> list) {
    if (list.isEmpty) return list;

    // 1. STRICT LOCAL FILTER: Ensure no allergens slip through and block ignored authors
    final filtered = list.where((r) {
      // Exclude blocked users
      if (_blockedUserIds.contains(r.authorId)) return false;

      if (userAllergies.isEmpty) return true;

      final rName = r.name.toLowerCase();
      final rTags = r.tags.map((e) => e.toLowerCase()).toSet();
      final rAllergens = r.allergens.map((e) => e.toLowerCase()).toSet();
      final rIngredients = r.ingredients.map((e) => e.name.toLowerCase()).toList();

      // Mapping for complex allergens (sub-ingredients)
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
        
        // Special Case: Allow "Gluten-Free" even if user has Gluten allergy
        if (a == "gluten") {
          bool isGlutenFree = rName.contains("gluten-free") || 
                             rName.contains("gluten free") ||
                             rTags.contains("gluten-free") ||
                             rTags.contains("gluten free");
          if (isGlutenFree) continue;
        }

        for (final term in searchTerms) {
          // Check explicit allergens list
          if (rAllergens.contains(term)) return false;
          
          // Check tags
          if (rTags.contains(term)) return false;
          
          // Check name
          if (rName.contains(term)) return false;

          // Check individual ingredients
          for (final ing in rIngredients) {
            if (ing.contains(term)) return false;
          }
        }
      }
      return true;
    }).toList();

    if (filtered.isEmpty) return [];
    if (_tagWeights.isEmpty) return filtered;

    // 2. Rerank remaining items by preference weights
    final scored = <MapEntry<Recipe, double>>[];
    for (final r in filtered) {
      double s = 0;
      for (final t in r.tags) {
        final w = _tagWeights[t.toLowerCase()] ?? 0;
        s += w.toDouble();
      }
      if (r.authorId.isNotEmpty && _followedAuthorIds.contains(r.authorId)) {
        s += 200;
      }
      if (_recentViewed.contains(r.id)) {
        s -= 300;
      }
      scored.add(MapEntry(r, s));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.map((e) => e.key).toList();
  }
  Future<void> _onTagTap(String tag) async {
    log("Tag tapped: $tag");
    setState(() {
      selectedTag = tag;
      loading = true;
      loadError = null;
    });

    try {
      final isAll = tag == "All";
      
      final user = _auth.currentUser;
      List<String> likedIds = [];
      if (user != null) {
         likedIds = await _recipeService.getLikedRecipeIds(user.uid);
      }

      // Use tag as both query and filter for better results
      final rec = await api.recommend(
        query: isAll ? "popular" : tag,
        tag: isAll ? null : tag,
        allergies: userAllergies,
        likedRecipeIds: likedIds,
        topK: 50,
        minRating: 0.0,
      );

      if (!mounted) return;
      setState(() {
        recommendations = _rerankByPreferences(rec);
        loading = false;
      });
      log("Tag results loaded: ${rec.length} recommendations");
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        loadError = e.toString();
        recommendations = const [];
      });
    }
  }

  void _openCategoryView() {
    final isAll = selectedTag == "All";
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoriesScreen(
          title: isAll ? "Quick ideas for you" : selectedTag,
          tag: selectedTag,
          allergies: userAllergies,
        ),
      ),
    );
  }

  void _openSearch({bool openFilters = false}) {
    Navigator.push(
      context, 
      MaterialPageRoute(builder: (_) => SearchScreen(openFilters: openFilters))
    ).then((_) {
      // Reset bottom nav to home when returning from search
      if (mounted) {
        setState(() => bottomIndex = 0);
      }
    });
  }

void _openUserProfile() {
  if (isNutritionistInUserView) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: false,
        builder: (_) => const NutritionistSettingsScreen(),
      ),
    ).then((_) {
      // Refresh home in case profile changed
      _loadHome();
    });
  } else {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: false,
        builder: (_) => const UserProfileScreen(),
      ),
    ).then((_) {
      // Refresh home in case profile changed
      _loadHome();
    });
  }
}


  void _openWeeklyRecipes() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoriesScreen(
          title: "Recipes of the Week",
          query: "top this week",
          allergies: userAllergies,
        ),
      ),
    );
  }

  void _openFollowingFeed() async {
    final followedAuthorIds = await _followService.getFollowedAuthorIds();
    if (!mounted) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoriesScreen(
          title: "People You Follow",
          authorIds: followedAuthorIds,
          allergies: userAllergies,
        ),
      ),
    );
  }

  void _openRecipe(Recipe r) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RecipeDetailsScreen(recipe: r)),
    ).then((_) => _loadHome());
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  void _onBottomTap(int i) {
    setState(() => bottomIndex = i);

    if (i == 1) _openSearch();

    if (i == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const UploadRecipeStep1()),
      ).then((_) {
        if (mounted) setState(() => bottomIndex = 0);
      });
    }

    if (i == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SavedRecipesScreen()),
      ).then((_) {
        if (mounted) setState(() => bottomIndex = 0);
      });
    }

    // 4 nutritionist tab (NOT user profile)
    if (i == 4) {
      if (isNutritionistInUserView) {
        _returnToNutritionistDashboard();
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NutritionistDiscoveryScreen()),
        ).then((_) {
          if (mounted) setState(() => bottomIndex = 0);
        });
      }
    }
  }

  Future<void> _returnToNutritionistDashboard() async {
    await ViewModeService().setUserView(false);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const NutritionistDashboard()),
      (route) => false,
    );
  }

  // ──────────────────── TAG ICON MAPPING (outline) ────────────────────
  IconData _tagIcon(String tag) {
    final t = tag.toLowerCase().replaceAll("recipes", "").trim();

    // Time
    if (t.contains('min') || t.contains('hour')) return Icons.timer_outlined;

    // Exact match first
    if (t == 'all') return Icons.grid_view_outlined;
    if (t == 'easy') return Icons.thumb_up_outlined;

    // Meal types
    if (t.contains('breakfast')) return Icons.free_breakfast_outlined;
    if (t.contains('lunch')) return Icons.lunch_dining_outlined;
    if (t.contains('dinner')) return Icons.dinner_dining_outlined;
    if (t.contains('snack')) return Icons.fastfood_outlined;

    // Food categories
    if (t.contains('dessert') || t.contains('desert')) return Icons.cake_outlined;
    if (t.contains('soup')) return Icons.soup_kitchen_outlined;
    if (t.contains('salad')) return Icons.eco_outlined;
    if (t.contains('pasta')) return Icons.ramen_dining_outlined;
    if (t.contains('rice')) return Icons.rice_bowl_outlined;
    if (t.contains('bread')) return Icons.bakery_dining_outlined;
    if (t.contains('sandwich')) return Icons.lunch_dining_outlined;
    if (t.contains('cookie') || t.contains('brownie')) return Icons.cookie_outlined;
    if (t.contains('beverage') || t.contains('drink')) return Icons.local_cafe_outlined;

    // Ingredients
    if (t.contains('chicken') || t.contains('poultry')) return Icons.set_meal_outlined;
    if (t.contains('beef') || t.contains('meat') || t.contains('pork')) return Icons.kebab_dining_outlined;
    if (t.contains('fish') || t.contains('seafood')) return Icons.set_meal_outlined;
    if (t.contains('egg')) return Icons.egg_outlined;
    if (t.contains('vegetable')) return Icons.spa_outlined;
    if (t.contains('fruit')) return Icons.apple_outlined;
    if (t.contains('cheese')) return Icons.circle_outlined;
    if (t.contains('nuts')) return Icons.scatter_plot_outlined;
    if (t.contains('beans')) return Icons.grain_outlined;
    if (t.contains('grain')) return Icons.grass_outlined;

    // Flavor / style
    if (t.contains('spicy')) return Icons.local_fire_department_outlined;
    if (t.contains('sweet')) return Icons.icecream_outlined;

    // Cuisine
    if (t.contains('asian')) return Icons.ramen_dining_outlined;
    if (t.contains('mexican') || t.contains('southwestern')) return Icons.restaurant_outlined;
    if (t.contains('italian')) return Icons.local_pizza_outlined;
    if (t.contains('european') || t.contains('canadian')) return Icons.public_outlined;
    if (t.contains('kosher')) return Icons.star_outline;

    // Health / diet
    if (t.contains('vegan') || t.contains('vegetarian')) return Icons.eco_outlined;
    if (t.contains('healthy')) return Icons.favorite_outline;
    if (t.contains('low') || t.contains('free of')) return Icons.do_not_disturb_alt_outlined;
    if (t.contains('high in') || t.contains('high protein')) return Icons.fitness_center_outlined;

    // Cooking method
    if (t.contains('oven') || t.contains('baked')) return Icons.bakery_dining_outlined;
    if (t.contains('stove')) return Icons.whatshot_outlined;
    if (t.contains('no cook')) return Icons.block_outlined;

    // Occasion / audience
    if (t.contains('kid')) return Icons.child_care_outlined;
    if (t.contains('large group') || t.contains('potluck')) return Icons.groups_outlined;
    if (t.contains('beginner')) return Icons.school_outlined;
    if (t.contains('inexpensive')) return Icons.savings_outlined;
    if (t.contains('weeknight')) return Icons.nightlight_outlined;

    // Season / holiday
    if (t.contains('winter') || t.contains('christmas')) return Icons.ac_unit_outlined;
    if (t.contains('summer')) return Icons.wb_sunny_outlined;
    if (t.contains('spring')) return Icons.local_florist_outlined;
    if (t.contains('thanksgiving')) return Icons.celebration_outlined;

    // Default
    return Icons.fastfood_outlined;
  }

  // ──────────────────── BUILD ────────────────────
  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    ResponsiveUtils.init(context);
    return Scaffold(
      backgroundColor: bg,
      extendBody: true,
      body: ClipRRect(
        borderRadius: BorderRadius.circular(30.sw),
        child: Container(
          color: widget.inShell ? Colors.transparent : bg,
          child: Stack(
            children: [
              // Background Pattern (Full Screen)
              if (!widget.inShell) const PatternBackground(),

              // Layout: Header + Content
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    SizedBox(height: 16.sh),
                    // Fixed Header
                    _topRow(),
                    SizedBox(height: 6.sh),

                    // Scrollable Content
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadHome,
                        color: orange,
                        backgroundColor: Colors.white,
                        child: ListView(
                          padding: EdgeInsets.only(bottom: 180.sh),
                          children: [
                            SizedBox(height: 6.sh),
                            _headline(),
                            SizedBox(height: 14.sh),

                            _searchBar(),
                            SizedBox(height: 18.sh),

                            _tagRow(),
                            SizedBox(height: 18.sh),

                            _heroCard(),
                            SizedBox(height: 22.sh),

                            _sectionHeader(
                              selectedTag == "All" ? "Quick ideas for you" : _beautify(selectedTag),
                              onSeeAll: _openCategoryView,
                            ),
                            SizedBox(height: 12.sh),
                            _horizontalCards(loading ? null : recommendations),

                            SizedBox(height: 24.sh),
                            _weeklySection(),

                            if (_followedAuthorIds.isNotEmpty) ...[
                              SizedBox(height: 24.sh),
                              _sectionHeader("From People You Follow", onSeeAll: _openFollowingFeed),
                              SizedBox(height: 12.sh),
                              _horizontalCards(loading ? null : followingFeed),
                            ],

                            if (loadError != null) ...[
                              SizedBox(height: 16.sh),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 22.sw),
                                child: Text(
                                  "API error: $loadError",
                                  style: TextStyle(
                                    color: purple.withValues(alpha: .8),
                                    fontFamily: "Satoshi",
                                    fontSize: 12.sp,
                                  ),
                                ),
                              ),
                              SizedBox(height: 10.sh),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 22.sw),
                                child: ElevatedButton(
                                  onPressed: _loadHome,
                                  child: const Text("Retry"),
                                ),
                              ),
                              SizedBox(height: 16.sh),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      bottomNavigationBar: widget.inShell 
          ? null 
          : HpBottomNav(
              currentIndex: bottomIndex,
              onTap: _onBottomTap,
              orange: orange,
              isNutritionistInUserView: isNutritionistInUserView,
            ),
    );
  }

  // ──────────────────── TOP ROW ────────────────────
  Widget _topRow() {
    final displayUrl = photoUrl ?? FirebaseAuth.instance.currentUser?.photoURL;
    final hasPhoto = displayUrl != null && displayUrl.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 22.sw),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _openUserProfile,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(50.sw),
              child: Container(
                width: 50.sw,
                height: 50.sw,
                color: const Color(0xFFD9D9D9),
                child: hasPhoto && displayUrl.startsWith("http")
                    ? Image.network(
                        displayUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Icon(Icons.person_rounded, color: purple, size: 28.sw),
                        ),
                      )
                    : Center(
                        child: Icon(Icons.person_rounded, color: purple, size: 28.sw),
                      ),
              ),
            ),
          ),
          const Spacer(),
          // Notification icon (replaced search)
          GestureDetector(
            onTap: _openNotifications,
            child: StreamBuilder<List<AppNotification>>(
              stream: NotificationService().streamNotifications(),
              builder: (context, snapshot) {
                final hasUnread = snapshot.hasData && snapshot.data!.any((n) => !n.isRead);
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Image.asset(
                      "assets/icons/notification.png",
                      width: 26.sw,
                      height: 26.sw,
                      color: purple,
                    ),
                    if (hasUnread)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 8.sw,
                          height: 8.sw,
                          decoration: BoxDecoration(
                            color: orange,
                            shape: BoxShape.circle,
                            border: Border.all(color: bg, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                );
              }
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────── HEADLINE (with orange "cook") ────────────────────
  Widget _headline() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 22.sw),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            color: purple,
            fontSize: 38.sp,
            fontWeight: FontWeight.w900,
            height: 1.1,
            fontFamily: "Satoshi",
          ),
          children: [
            const TextSpan(text: "What would you\nlike to "),
            TextSpan(
              text: "cook",
              style: TextStyle(color: orange),
            ),
            const TextSpan(text: "?"),
          ],
        ),
      ),
    );
  }

  // ──────────────────── SEARCH BAR (with filter icon) ────────────────────
  Widget _searchBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 22.sw),
      child: GestureDetector(
        onTap: _openSearch,
        child: Container(
          height: 44.sh,
          padding: EdgeInsets.only(left: 16.sw, right: 4.sw),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28.sw),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: purple.withValues(alpha: 0.45), size: 20.sw),
              SizedBox(width: 10.sw),
              Expanded(
                child: Text(
                  "Search recipes, ingredients...",
                  style: TextStyle(
                    color: purple.withValues(alpha: 0.45),
                    fontSize: 13.sp,
                    fontFamily: "Satoshi",
                  ),
                ),
              ),
              // Voice search button (formerly filter)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _toggleListening();
                },
                child: Container(
                  width: 36.sw,
                  height: 36.sw,
                  decoration: BoxDecoration(
                    color: _isListening ? orange : purple,
                    borderRadius: BorderRadius.circular(18.sw),
                    boxShadow: _isListening ? [
                      BoxShadow(color: orange.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 2)
                    ] : null,
                  ),
                  child: Icon(
                    _isListening ? Icons.graphic_eq_rounded : Icons.mic_rounded, 
                    color: Colors.white, 
                    size: 18.sw
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────── TAG ROW (rounded squares with icon + underline) ────────────────────
  Widget _tagRow() {
    final chips = tags.isEmpty
        ? const ["All", "Breakfast", "Lunch", "Dinner", "Pakistani", "Asian", "Dessert", "Snack", "Soup", "Salad", "Chicken", "Seafood", "Rice", "Beverage", "Baked", "Spicy"]
        : tags;

    return SizedBox(
      height: 68.sh,
      child: ListView.separated(
        controller: _tagScrollController,
        padding: EdgeInsets.symmetric(horizontal: 22.sw),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, i) {
          final t = chips[i];
          final isSelected = t == selectedTag;

          return GestureDetector(
            onTap: () {
              // Smooth scroll to center the tapped tag
              final screenW = MediaQuery.of(context).size.width;
              final scale = screenW / 375;
              final targetOffset = (i * (54 + 8) * scale) - (screenW / 2) + ((54 / 2 + 22) * scale);
              _tagScrollController.animateTo(
                targetOffset.clamp(0.0, _tagScrollController.position.maxScrollExtent),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
              );
              _onTagTap(t);
            },
            child: SizedBox(
              width: 54.sw,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    width: 54.sw,
                    height: 52.sh,
                    decoration: BoxDecoration(
                      color: isSelected ? purple : chipBg,
                      borderRadius: BorderRadius.circular(12.sw),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: purple.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _tagIcon(t),
                          color: isSelected ? orange : purple,
                          size: 16.sw,
                        ),
                        SizedBox(height: 3.sh),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 3.sw),
                          child: Text(
                            _beautify(t),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isSelected ? orange : purple,
                              fontSize: 8.sp,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              fontFamily: "Satoshi",
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Orange underline — fixed width, animate opacity
                  SizedBox(height: 3.sh),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: isSelected ? 1.0 : 0.0,
                    child: Container(
                      width: 20.sw,
                      height: 2.5.sh,
                      decoration: BoxDecoration(
                        color: orange,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => SizedBox(width: 6.sw),
        itemCount: chips.length,
      ),
    );
  }

  // ──────────────────── HERO CARD (Stack with ClipPath) ────────────────────
  Widget _heroCard() {
  if (recommendations.isEmpty) {
    if (loading) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 22.sw),
        child: Container(
          height: 200.sh,
          decoration: BoxDecoration(
            color: purple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(28.sw),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: SkeletonBox(
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: BorderRadius.circular(28.sw),
                ),
              ),
              Positioned(
                bottom: 20.sh,
                left: 20.sw,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 150.sw, height: 20.sh),
                    SizedBox(height: 10.sh),
                    SkeletonBox(width: 100.sw, height: 14.sh),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox();
  }

  final r = recommendations.first;
  final timeText = r.minutes > 0 ? "${r.minutes} min" : "";
  final diffText = r.difficulty ?? "";

  return Padding(
    padding: EdgeInsets.symmetric(horizontal: 22.sw),
    child: GestureDetector(
      onTap: () => _openRecipe(r),
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 700),
        tween: Tween(begin: 0.92, end: 1),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) {
          return Transform.scale(scale: scale, child: child);
        },
        child: Container(
          height: 210.sh,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28.sw),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 35,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28.sw),
            child: Stack(
              children: [
                // 🌄 IMAGE (cinematic zoom)
                Positioned.fill(
                  child: Transform.scale(
                    scale: 1.12,
                    child: Image.network(
                      r.imageUrl ?? "",
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: Colors.grey.shade900),
                    ),
                  ),
                ),

                // 🌑 CINEMATIC GRADIENT
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.7),
                          Colors.black.withValues(alpha: 0.15),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),

                // 🔥 BREATHING GLOW (animated feel - Orange)
                Positioned(
                  bottom: -40,
                  left: -40,
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(seconds: 2),
                    tween: Tween(begin: 0.2, end: 0.35),
                    curve: Curves.easeInOut,
                    builder: (context, value, child) {
                      return Container(
                        width: 160.sw,
                        height: 160.sw,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: orange.withValues(alpha: value),
                          boxShadow: [
                            BoxShadow(
                              color: orange.withValues(alpha: value),
                              blurRadius: 80,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // 💜 PURPLE SPLASH (Top Right Glow)
                Positioned(
                  top: -60,
                  right: -60,
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(seconds: 3),
                    tween: Tween(begin: 0.1, end: 0.25),
                    curve: Curves.easeInOut,
                    builder: (context, value, child) {
                      return Container(
                        width: 180.sw,
                        height: 180.sw,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: purple.withValues(alpha: value),
                          boxShadow: [
                            BoxShadow(
                              color: purple.withValues(alpha: value),
                              blurRadius: 90,
                              spreadRadius: 15,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // 🏷️ BADGE
                Positioned(
                  top: 14.sh,
                  left: 14.sw,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 10.sw, vertical: 5.sh),
                    decoration: BoxDecoration(
                      color: orange,
                      borderRadius: BorderRadius.circular(12.sw),
                      boxShadow: [
                        BoxShadow(
                          color: orange.withValues(alpha: 0.4),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Text(
                      "TODAY'S PICK",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),

                // 🧊 GLASS CONTENT
                Positioned(
                  left: 14.sw,
                  right: 14.sw,
                  bottom: 12.sh,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20.sw),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16.sw, vertical: 10.sh),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(18.sw),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // TITLE
                            Text(
                              r.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),

                            SizedBox(height: 4.sh),

                            // RATING
                            Row(
                              children: [
                                Icon(Icons.star_rounded, color: orange, size: 14.sw),
                                SizedBox(width: 4.sw),
                                Text(
                                  r.avgRating.toStringAsFixed(1),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(width: 4.sw),
                                Text(
                                  "(${r.reviewCount})",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10.sp,
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 6.sh),

                            // META INFO
                            Row(
                              children: [
                                if (timeText.isNotEmpty) ...[
                                  Icon(Icons.access_time,
                                      color: Colors.white70, size: 14.sw),
                                  SizedBox(width: 4.sw),
                                  Text(
                                    timeText,
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10.sp,
                                    ),
                                  ),
                                ],
                                if (diffText.isNotEmpty) ...[
                                  SizedBox(width: 10.sw),
                                  Icon(Icons.signal_cellular_alt,
                                      color: Colors.white70, size: 14.sw),
                                  SizedBox(width: 4.sw),
                                  Text(
                                    diffText,
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10.sp,
                                    ),
                                  ),
                                ],
                              ],
                            ),

                            SizedBox(height: 10.sh),
                            // CTA BUTTON (premium feel)
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12.sw, vertical: 7.sh),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    orange,
                                    orange.withValues(alpha: 0.75),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(22.sw),
                                boxShadow: [
                                  BoxShadow(
                                    color: orange.withValues(alpha: 0.35),
                                    blurRadius: 18,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "View Recipe",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(width: 6.sw),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    color: Colors.white,
                                    size: 14.sw,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  // ──────────────────── WEEKLY FEATURE SECTION ────────────────────
  Widget _weeklySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader("Weekly Trending", onSeeAll: _openWeeklyRecipes),
        SizedBox(height: 12.sh),
        _weeklyFeatureCard(),
      ],
    );
  }

  // ──────────────────── WEEKLY FEATURE CARD (single big card) ────────────────────
  Widget _weeklyFeatureCard() {
    if (loading) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 22.sw),
        child: Container(
          height: 220.sh,
          decoration: BoxDecoration(
            color: purple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(28.sw),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: SkeletonBox(
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: BorderRadius.circular(28.sw),
                ),
              ),
              Positioned(
                top: 16.sh,
                left: 16.sw,
                child: SkeletonBox(width: 120.sw, height: 28.sh, borderRadius: BorderRadius.circular(12.sw)),
              ),
              Positioned(
                bottom: 25.sh,
                left: 20.sw,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 180.sw, height: 22.sh),
                    SizedBox(height: 10.sh),
                    SkeletonBox(width: 120.sw, height: 16.sh),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (weekly.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 22.sw),
        child: Text(
          "No trending recipes this week.",
          style: TextStyle(
            color: purple.withValues(alpha: 0.7),
            fontSize: 14.sp,
            fontFamily: "Satoshi",
          ),
        ),
      );
    }

    final r = weekly.first;
    final timeText = r.minutes > 0 ? "${r.minutes} min" : "";
    final diffText = r.difficulty ?? "";

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 22.sw),
      child: GestureDetector(
        onTap: () => _openRecipe(r),
        child: Container(
          height: 220.sh,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28.sw),
            boxShadow: [
              BoxShadow(
                color: orange.withValues(alpha: 0.25),
                blurRadius: 35,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28.sw),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.network(
                    r.imageUrl ?? "",
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade900),
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.8),
                          Colors.black.withValues(alpha: 0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 16.sh,
                  left: 16.sw,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.sw, vertical: 6.sh),
                    decoration: BoxDecoration(
                      color: orange,
                      borderRadius: BorderRadius.circular(12.sw),
                    ),
                    child: Text(
                      "TRENDING",
                      style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Positioned(
                  left: 20.sw,
                  right: 20.sw,
                  bottom: 20.sh,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        r.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22.sp,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 8.sh),
                      Row(
                        children: [
                          Icon(Icons.star_rounded, color: orange, size: 14.sw),
                          SizedBox(width: 4.sw),
                          Text(
                            r.avgRating.toStringAsFixed(1),
                            style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.bold),
                          ),
                          if (timeText.isNotEmpty) ...[
                            SizedBox(width: 12.sw),
                            Icon(Icons.schedule_rounded, color: Colors.white, size: 14.sw),
                            SizedBox(width: 4.sw),
                            Text(timeText, style: TextStyle(color: Colors.white, fontSize: 12.sp)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────── SECTION HEADER ────────────────────
  Widget _sectionHeader(String title, {required VoidCallback onSeeAll}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 22.sw),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: purple,
                fontSize: 22.sp,
                fontWeight: FontWeight.bold,
                fontFamily: "Satoshi",
              ),
            ),
          ),
          GestureDetector(
            onTap: onSeeAll,
            child: Text(
              "See all",
              style: TextStyle(
                color: purple,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                fontFamily: "Satoshi",
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────── CARDS ────────────────────
  Widget _horizontalCards(List<Recipe>? list) {
    if (list == null) {
      return SizedBox(
        height: 240.sh,
        child: ListView.separated(
          padding: EdgeInsets.symmetric(horizontal: 22.sw),
          scrollDirection: Axis.horizontal,
          itemBuilder: (_, __) => RecipeCardSkeleton(width: 135.sw),
          separatorBuilder: (_, __) => SizedBox(width: 8.sw),
          itemCount: 3,
        ),
      );
    }

    if (list.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 22.sw),
        child: Text(
          "No recipes found for this filter.",
          style: TextStyle(
            color: purple.withValues(alpha: 0.8),
            fontFamily: "Satoshi",
            fontSize: 14.sp,
          ),
        ),
      );
    }

    return SizedBox(
      height: 190.sh,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 22.sw),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, i) => _recipeCard(list[i]),
        separatorBuilder: (_, __) => SizedBox(width: 14.sw),
        itemCount: list.length,
      ),
    );
  }

  Widget _recipeCard(Recipe r) {
    return SizedBox(
      width: 135.sw,
      child: RecipeCard(
        recipe: r,
        width: 135.sw,
        aspectRatio: 135 / 190,
        onTap: () => _openRecipe(r),
      ),
    );
  }
}
