import 'dart:developer';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_api_service.dart';
import 'package:hidden_pantry_app/core/widgets/skeletons.dart';
import 'package:hidden_pantry_app/core/widgets/home_bottom_nav.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_service.dart';

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
    setState(() {
      loading = true;
      loadError = null;
    });

    try {
      // 1. Fetch user data and tags concurrently
      List<String> fetchedTags = [];
      List<String> likedIds = [];
      List<String> followedIds = [];
      
      final user = FirebaseAuth.instance.currentUser;
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
          _recipeService.getLikedRecipeIds(user.uid).then((v) => likedIds = v).catchError((_) => <String>[])
        );

        initialFutures.add(
          FirebaseFirestore.instance.collection('users').doc(user.uid).collection('views')
              .orderBy('lastViewed', descending: true).limit(200).get().then((snap) {
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
            allDocs.addAll(snap.docs.map((d) => Recipe.fromJson(d.data())));
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

        api.recommend(
          query: "top this week", tag: null, allergies: userAllergies,
          likedRecipeIds: likedIds, topK: 50, minRating: 0.0,
        ).then((v) => week = v).catchError((_) => <Recipe>[]),
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
    );
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
    ResponsiveUtils.init(context);
    return Scaffold(
      backgroundColor: bg,
      extendBody: true,
      body: ClipRRect(
        borderRadius: BorderRadius.circular(30.sw),
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
                            _weeklyHeader(),
                            SizedBox(height: 12.sh),
                            _weeklyFeatureCard(),

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
                        errorBuilder: (_, __, ___) => Padding(
                          padding: EdgeInsets.all(12.sw),
                          child: Image.asset(
                            "assets/icons/users.png", 
                             color: purple,
                             fit: BoxFit.contain,
                          ),
                        ),
                      )
                    : Padding(
                        padding: EdgeInsets.all(12.sw),
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
        ? const ["All", "Breakfast", "Lunch", "Dinner", "Dessert", "Snack", "Soup", "Salad", "Pasta", "Sandwich", "Chicken", "Seafood", "Rice", "Beverage", "Baked", "Spicy"]
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
          child: SkeletonBox(
            width: double.infinity,
            height: 180.sh,
            borderRadius: BorderRadius.circular(24.sw),
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
        child: Container(
          height: 180.sh,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24.sw),
            boxShadow: [
              BoxShadow(
                color: purple.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24.sw),
            child: Stack(
              children: [
                // Background image (full)
                Positioned.fill(
                  child: Image.network(
                    r.imageUrl ?? "",
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: chipBg),
                  ),
                ),
                // Dark gradient overlay
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          purple,
                          purple.withValues(alpha: 0.92),
                          purple.withValues(alpha: 0.45),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.45, 0.7, 1.0],
                      ),
                    ),
                  ),
                ),
                // Text content on left
                Positioned(
                  left: 18.sw,
                  top: 18.sh,
                  bottom: 18.sh,
                  right: 120.sw,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.sw, vertical: 4.sh),
                        decoration: BoxDecoration(
                          color: orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8.sw),
                        ),
                        child: Text(
                          "🔥 TODAY'S PICK",
                          style: TextStyle(
                            color: orange,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w800,
                            fontFamily: "Satoshi",
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      SizedBox(height: 8.sh),
                      Text(
                        r.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800,
                          fontFamily: "Satoshi",
                          height: 1.2,
                        ),
                      ),
                      if (timeText.isNotEmpty || diffText.isNotEmpty) ...[
                        SizedBox(height: 6.sh),
                        Row(
                          children: [
                            if (timeText.isNotEmpty) ...[
                              Icon(Icons.access_time_rounded, color: Colors.white70, size: 14.sw),
                              SizedBox(width: 4.sw),
                              Text(
                                timeText,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11.sp,
                                  fontFamily: "Satoshi",
                                ),
                              ),
                            ],
                            if (timeText.isNotEmpty && diffText.isNotEmpty)
                              SizedBox(width: 10.sw),
                            if (diffText.isNotEmpty) ...[
                              Icon(Icons.signal_cellular_alt_rounded, color: Colors.white70, size: 14.sw),
                              SizedBox(width: 4.sw),
                              Text(
                                diffText,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11.sp,
                                  fontFamily: "Satoshi",
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                      SizedBox(height: 10.sh),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 14.sw, vertical: 8.sh),
                        decoration: BoxDecoration(
                          color: orange,
                          borderRadius: BorderRadius.circular(20.sw),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "View Recipe",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                                fontFamily: "Satoshi",
                              ),
                            ),
                            SizedBox(width: 4.sw),
                            Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14.sw),
                          ],
                        ),
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
          SizedBox(width: 8.sw),
          GestureDetector(
            onTap: onSeeAll,
            child: Text(
              "See all",
              style: TextStyle(
                color: purple,
                fontSize: 12.sp,
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

  // ──────────────────── WEEKLY HEADER (RichText underline) ────────────────────
  Widget _weeklyHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 22.sw),
      child: Row(
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  color: purple,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                  fontFamily: "Satoshi",
                ),
                children: [
                  const TextSpan(text: "Recipes of the "),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Week",
                          style: TextStyle(
                            color: purple,
                            fontSize: 22.sp,
                            fontWeight: FontWeight.bold,
                            fontFamily: "Satoshi",
                          ),
                        ),
                        Container(
                          height: 3.sh,
                          width: 50.sw,
                          decoration: BoxDecoration(
                            color: orange,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 8.sw),
          GestureDetector(
            onTap: _openWeeklyRecipes,
            child: Text(
              "See all",
              style: TextStyle(
                color: purple,
                fontSize: 12.sp,
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

  // ──────────────────── WEEKLY FEATURE CARD (single big card) ────────────────────
  Widget _weeklyFeatureCard() {
    if (loading) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 22.sw),
        child: SkeletonBox(
          width: double.infinity,
          height: 160.sh,
          borderRadius: BorderRadius.all(Radius.circular(24.sw)),
        ),
      );
    }

    if (weekly.isEmpty) return const SizedBox();

    final r = weekly.first;
    final timeText = r.minutes > 0 ? "${r.minutes} min" : "";
    final diffText = r.difficulty ?? "";

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 22.sw),
      child: GestureDetector(
        onTap: () => _openRecipe(r),
        child: Container(
          height: 160.sh,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24.sw),
            boxShadow: [
              BoxShadow(
                color: purple.withValues(alpha: 0.15),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24.sw),
            child: Stack(
              children: [
                // Background Image (full)
                Positioned.fill(
                  child: Image.network(
                    r.imageUrl ?? "",
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: chipBg),
                  ),
                ),
                // Gradient Overlay
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          purple.withValues(alpha: 0.2),
                          purple.withValues(alpha: 0.85),
                        ],
                        stops: const [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),
                ),
                // Badge
                Positioned(
                  top: 14.sh,
                  left: 14.sw,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.sw, vertical: 4.sh),
                    decoration: BoxDecoration(
                      color: orange,
                      borderRadius: BorderRadius.circular(8.sw),
                    ),
                    child: Text(
                      "🔥 TRENDING",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w900,
                        fontFamily: "Satoshi",
                      ),
                    ),
                  ),
                ),
                // Content
                Positioned(
                  left: 16.sw,
                  bottom: 16.sh,
                  right: 60.sw,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        r.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800,
                          fontFamily: "Satoshi",
                        ),
                      ),
                      SizedBox(height: 4.sh),
                      Row(
                        children: [
                          if (timeText.isNotEmpty) ...[
                            Icon(Icons.access_time_rounded, color: Colors.white70, size: 12.sw),
                            SizedBox(width: 4.sw),
                            Text(timeText, style: TextStyle(color: Colors.white70, fontSize: 11.sp)),
                          ],
                          if (timeText.isNotEmpty && diffText.isNotEmpty) SizedBox(width: 10.sw),
                          if (diffText.isNotEmpty) ...[
                            Icon(Icons.signal_cellular_alt_rounded, color: Colors.white70, size: 12.sw),
                            SizedBox(width: 4.sw),
                            Text(diffText, style: TextStyle(color: Colors.white70, fontSize: 11.sp)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Arrow
                Positioned(
                  right: 16.sw,
                  bottom: 16.sh,
                  child: Container(
                    width: 36.sw,
                    height: 36.sw,
                    decoration: BoxDecoration(color: orange, shape: BoxShape.circle),
                    child: Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18.sw),
                  ),
                ),
              ],
            ),
          ),
        ),
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
          itemBuilder: (_, __) => _recipeCardSkeleton(),
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

  Widget _recipeCardSkeleton() {
    return SizedBox(
      width: 155.sw,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(
            width: 135.sw,
            height: 150.sh,
            borderRadius: BorderRadius.all(Radius.circular(18.sw)),
          ),
          SizedBox(height: 10.sh),
          SkeletonBox(
            width: 110.sw,
            height: 14.sh,
            borderRadius: BorderRadius.all(Radius.circular(10.sw)),
          ),
          SizedBox(height: 8.sh),
          SkeletonBox(
            width: 70.sw,
            height: 10.sh,
            borderRadius: BorderRadius.all(Radius.circular(10.sw)),
          ),
        ],
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

class _HomeBackgroundPattern extends StatelessWidget {
  const _HomeBackgroundPattern();

  @override
  Widget build(BuildContext context) {
    

    final stroke = const Color(0xFFF5DDCE);

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: (-154).sw,
            top: (-14).sh,
            child: Transform.rotate(
              angle: 21 * math.pi / 180,
              child: Container(
                width: 271.sw,
                height: 159.sh,
                decoration: BoxDecoration(
                  border: Border.all(color: stroke),
                  borderRadius: BorderRadius.all(
                    Radius.elliptical(136.sw, 80.sh),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: (-149).sw,
            top: (-100).sh,
            child: Transform.rotate(
              angle: 4 * math.pi / 180,
              child: Container(
                width: 303.sw,
                height: 329.sh,
                decoration: BoxDecoration(
                  border: Border.all(color: stroke),
                  borderRadius: BorderRadius.all(
                    Radius.elliptical(152.sw, 165.sh),
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