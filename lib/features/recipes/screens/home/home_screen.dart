import 'dart:developer';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_api_service.dart';
import 'package:hidden_pantry_app/core/widgets/skeletons.dart';
import 'package:hidden_pantry_app/core/widgets/home_bottom_nav.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_service.dart';

import 'package:hidden_pantry_app/features/recipes/screens/recipe_details.dart';
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
import 'package:hidden_pantry_app/features/recipes/widgets/recipe_rating_widget.dart';

class HomeScreen extends StatefulWidget {
  final bool inShell;
  const HomeScreen({super.key, this.inShell = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  final RecipeService _recipeService = RecipeService();
  final RecipeApiService api =
      const RecipeApiService(baseUrl: ApiConstants.baseUrl);

  final Color bg = const Color(0xFFFFF3EB);
  final Color chipBg = const Color(0xFFF9E3D5);
  final Color purple = const Color(0xFF462F4D);
  final Color brown = const Color(0xFF433020);
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

  @override
  void initState() {
    super.initState();
    _checkNutritionistStatus();
    _loadHome();
  }

  Future<void> _checkNutritionistStatus() async {
    final isNutr = await ViewModeService().isNutritionist();
    if (mounted) {
      setState(() => isNutritionistInUserView = isNutr);
    }
  }

  Future<void> _loadHome() async {
    setState(() {
      loading = true;
      loadError = null;
    });

    try {
      // 1. Fetch user allergies first
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection("users").doc(user.uid).get();
        final data = doc.data();
        if (data != null) {
            final list = data['allergies'];
            if (list is List) {
              userAllergies = list.map((e) => e.toString()).toList();
            }
            photoUrl = (data['photoUrl'] as String?)?.trim();
             // Fallback to Auth if Firestore is empty but Auth has it (rare case if not synced)
            photoUrl ??= user.photoURL;
            final tw = data['tagWeights'];
            if (tw is Map) {
              _tagWeights = tw.map((k, v) => MapEntry(k.toString().toLowerCase(), num.tryParse(v.toString()) ?? 0));
            }
        }
      }

      final fetchedTags = await api.fetchTags(limit: 50);
      final fixedTags = _fixTags(fetchedTags);

      // 2. Fetch liked recipes for personalization
      List<String> likedIds = [];
      List<String> followedIds = [];
      if (user != null) {
        likedIds = await _recipeService.getLikedRecipeIds(user.uid);
        try {
          final recentSnap = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('views')
              .orderBy('lastViewed', descending: true)
              .limit(200)
              .get();
          _recentViewed = recentSnap.docs.map((d) => d.id).toSet();
        } catch (_) {}
        try {
          followedIds = await _followService.getFollowedAuthorIds();
          _followedAuthorIds = followedIds.toSet();
        } catch (_) {}
      }

      final rec = await api.recommend(
        query: "popular",
        tag: selectedTag,
        allergies: userAllergies,
        likedRecipeIds: likedIds,
        topK: 50,
        minRating: 0.0,
      );

      final week = await api.recommend(
        query: "top this week",
        tag: null, // Always global
        allergies: userAllergies,
        likedRecipeIds: likedIds,
        topK: 50,
        minRating: 0.0,
      );

      // 3. Fetch Following Feed
      final feed = await api.fetchFollowingFeed(followedIds).catchError((e) {
        log("Home: Following Feed error: $e");
        return <Recipe>[];
      });

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
    if (_tagWeights.isEmpty || list.isEmpty) return list;
    final scored = <MapEntry<Recipe, double>>[];
    for (final r in list) {
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
      
      final user = FirebaseAuth.instance.currentUser;
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
          title: isAll ? "Recommendation" : selectedTag,
          tag: selectedTag,
          allergies: userAllergies,
        ),
      ),
    );
  }

  void _openSearch() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())).then((_) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      body: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Container(
          color: bg,
          child: Stack(
            children: [
              // Background Pattern (Full Screen)
              const _HomeBackgroundPattern(),

              // Layout: Header + Content
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    // Fixed Header
                    _topRow(),
                    const SizedBox(height: 10),

                    // Scrollable Content
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadHome,
                        color: orange,
                        backgroundColor: Colors.white,
                        child: ListView(
                          padding: const EdgeInsets.only(bottom: 180),
                          children: [
                            const SizedBox(height: 10),
                            _headline(),
                            const SizedBox(height: 18),
                            _tagRow(),
                            const SizedBox(height: 22),

                            _sectionHeader(
                              selectedTag == "All" ? "Recommendation" : _beautify(selectedTag),
                              onSeeAll: _openCategoryView,
                            ),
                            const SizedBox(height: 12),
                            _horizontalCards(loading ? null : recommendations),

                            const SizedBox(height: 18),
                            _sectionHeader("Recipes of the Week", onSeeAll: _openWeeklyRecipes),
                            const SizedBox(height: 12),
                            _horizontalCards(loading ? null : weekly),

                            if (followingFeed.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              _sectionHeader("From People You Follow", onSeeAll: _openFollowingFeed),
                              const SizedBox(height: 12),
                              _horizontalCards(followingFeed),
                            ],

                            if (loadError != null) ...[
                              const SizedBox(height: 16),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 22),
                                child: Text(
                                  "API error: $loadError",
                                  style: TextStyle(
                                    color: purple.withValues(alpha: .8),
                                    fontFamily: "Satoshi",
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 22),
                                child: ElevatedButton(
                                  onPressed: _loadHome,
                                  child: const Text("Retry"),
                                ),
                              ),
                              const SizedBox(height: 16),
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

  Widget _topRow() {
    // Use the fetched photoUrl, fallback to Auth if not loaded yet (though loading handles this)
    final displayUrl = photoUrl ?? FirebaseAuth.instance.currentUser?.photoURL;
    final hasPhoto = displayUrl != null && displayUrl.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _openUserProfile,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: Container(
                width: 50,
                height: 50,
                color: const Color(0xFFD9D9D9),
                child: hasPhoto && displayUrl.startsWith("http")
                    ? Image.network(
                        displayUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Image.asset(
                            "assets/icons/users.png", 
                             color: purple,
                             fit: BoxFit.contain,
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Image.asset(
                          "assets/icons/users.png",
                          color: purple,
                          fit: BoxFit.contain,
                        ),
                      ),
              ),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _openSearch,
            child: Image.asset("assets/icons/Search.png", width: 22, height: 22),
          ),
        ],
      ),
    );
  }

  Widget _headline() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Text(
        "What would you\nlike to cook?",
        style: TextStyle(
          color: purple,
          fontSize: 40,
          fontWeight: FontWeight.w900,
          height: 1.1,
          fontFamily: "Satoshi",
        ),
      ),
    );
  }

  Widget _tagRow() {
    final chips = tags.isEmpty
        ? const ["All", "Breakfast", "Lunch", "Dinner", "Dessert", "Snack", "Soup", "Salad", "Pasta", "Sandwich", "Chicken", "Seafood", "Rice", "Beverage", "Baked", "Spicy"]
        : tags;

    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, i) {
          final t = chips[i];
          final isSelected = t == selectedTag;

          return GestureDetector(
            onTap: () => _onTagTap(t),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? orange : chipBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _beautify(t),
                style: TextStyle(
                  color: isSelected ? Colors.white : purple,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontFamily: "Satoshi",
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemCount: chips.length,
      ),
    );
  }

  Widget _sectionHeader(String title, {required VoidCallback onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: purple,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: "Satoshi",
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onSeeAll,
            child: Text(
              "See all",
              style: TextStyle(
                color: brown,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
                fontFamily: "Satoshi",
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _horizontalCards(List<Recipe>? list) {
    if (list == null) {
      return SizedBox(
        height: 270,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          scrollDirection: Axis.horizontal,
          itemBuilder: (_, __) => _recipeCardSkeleton(),
          separatorBuilder: (_, __) => const SizedBox(width: 16),
          itemCount: 3,
        ),
      );
    }

    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Text(
          "No recipes found for this filter.",
          style: TextStyle(
            color: purple.withValues(alpha: 0.8),
            fontFamily: "Satoshi",
          ),
        ),
      );
    }

    return SizedBox(
      height: 270,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, i) => _recipeCard(list[i]),
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemCount: list.length,
      ),
    );
  }

  Widget _recipeCardSkeleton() {
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SkeletonBox(
            width: 160,
            height: 180,
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          SizedBox(height: 10),
          SkeletonBox(
            width: 110,
            height: 14,
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          SizedBox(height: 8),
          SkeletonBox(
            width: 70,
            height: 10,
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ],
      ),
    );
  }

  Widget _recipeCard(Recipe r) {
    final imageUrl = r.imageUrl;
    final hasImage = imageUrl != null && imageUrl.trim().isNotEmpty;

    return GestureDetector(
      onTap: () => _openRecipe(r),
      child: SizedBox(
        width: 160,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(
                aspectRatio: 160 / 180,
                child: hasImage && imageUrl.startsWith("http")
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const SkeletonBox(
                            width: double.infinity,
                            height: double.infinity,
                          );
                        },
                        errorBuilder: (_, __, ___) => Image.asset(
                          "assets/Logos/recipe_placeholder.jpg",
                          fit: BoxFit.cover,
                        ),
                      )
                    : Image.asset(
                        "assets/Logos/recipe_placeholder.jpg",
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              r.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: purple,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                fontFamily: "Satoshi",
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  "${r.minutes} min  •  ",
                  style: TextStyle(
                    color: purple.withValues(alpha: 0.75),
                    fontSize: 11,
                    fontFamily: "Satoshi",
                  ),
                ),
                RecipeRatingWidget(
                  recipeId: r.id,
                  initialRating: r.avgRating,
                  style: TextStyle(
                    color: purple.withValues(alpha: 0.75),
                    fontSize: 11,
                    fontFamily: "Satoshi",
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeBackgroundPattern extends StatelessWidget {
  const _HomeBackgroundPattern();

  @override
  Widget build(BuildContext context) {
    const baseW = 393.0;
    const baseH = 852.0;

    final size = MediaQuery.of(context).size;
    double sx(double v) => v * (size.width / baseW);
    double sy(double v) => v * (size.height / baseH);

    final stroke = const Color(0xFFF5DDCE);

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: sx(-154),
            top: sy(-14),
            child: Transform.rotate(
              angle: 21 * math.pi / 180,
              child: Container(
                width: sx(271),
                height: sy(159),
                decoration: BoxDecoration(
                  border: Border.all(color: stroke),
                  borderRadius: BorderRadius.all(
                    Radius.elliptical(sx(136), sy(80)),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: sx(-149),
            top: sy(-100),
            child: Transform.rotate(
              angle: 4 * math.pi / 180,
              child: Container(
                width: sx(303),
                height: sy(329),
                decoration: BoxDecoration(
                  border: Border.all(color: stroke),
                  borderRadius: BorderRadius.all(
                    Radius.elliptical(sx(152), sy(165)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}



