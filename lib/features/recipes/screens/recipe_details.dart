import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_api_service.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/core/widgets/skeletons.dart';
import 'cooking_details.dart';
import 'package:hidden_pantry_app/core/constants/api_constants.dart';
import 'package:hidden_pantry_app/core/utils/glass_dialog.dart';
import 'package:hidden_pantry_app/features/recipes/screens/reviews/reviews.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_service.dart';
import 'package:hidden_pantry_app/features/recipes/services/local_recipe_service.dart';
import 'package:hidden_pantry_app/core/widgets/add_to_cookbook_bottom_sheet.dart';
import 'author_profile.dart';
import 'package:hidden_pantry_app/features/recipes/widgets/recipe_rating_widget.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/utils/ingredient_icon_mapper.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';
import 'package:flutter/rendering.dart';
import 'package:hidden_pantry_app/features/recipes/widgets/recipe_details_animations.dart';
import 'package:hidden_pantry_app/features/recipes/widgets/recipe_details_fab.dart';
import 'package:hidden_pantry_app/features/recipes/widgets/recipe_details_states.dart';
import 'package:hidden_pantry_app/features/user/services/subscription_service.dart';
import 'package:hidden_pantry_app/features/user/screens/premium_paywall_screen.dart';
import 'package:hidden_pantry_app/features/user/screens/tier_comparison_screen.dart';

class RecipeDetailsScreen extends StatefulWidget {
  final Recipe recipe;
  final RecipeApiService? apiService;
  final RecipeService? recipeService;

  const RecipeDetailsScreen({
    super.key,
    required this.recipe,
    this.apiService,
    this.recipeService,
  });

  @override
  State<RecipeDetailsScreen> createState() => _RecipeDetailsScreenState();
}

class _RecipeDetailsScreenState extends State<RecipeDetailsScreen> {
  static const Color bgColor = Color(0xFFFFF3EB);
  static const Color cardColor = Color(0xFFF9E3D5);
  static const Color textColor = Color(0xFF462F4D);
  static const Color orange = Color(0xFFEF8A54);
  static const Color orange2 = Color(0xFFE48E5B);

  late final RecipeApiService api;
  late Recipe _recipe;
  bool _loading = true;
  String? _error;
  int _authorRecipeCount = 0;
  List<Recipe> _authorRecipes = [];

  bool _liked = false;
  bool _bookmarked = false;
  bool _isDownloaded = false;
  int _remainingDownloads = 0;
  bool _isPremium = false;

  int _servings = 1;
  bool _nutritionExpanded = false;

  late final RecipeService _recipeService;
  final LocalRecipeService _localService = LocalRecipeService();
  final ScrollController _scrollController = ScrollController();
  late final PageController _authorPageController;
  double _authorPage = 0.0;
  bool _fabExpanded = false;
  bool get _isUnderTest => widget.apiService != null;

  @override
  void initState() {
    super.initState();
    api = widget.apiService ?? const RecipeApiService(baseUrl: ApiConstants.baseUrl);
    _recipeService = widget.recipeService ?? RecipeService();

    // Start with passed recipe
    _recipe = widget.recipe;
    _servings = (_recipe.baseServings <= 0) ? 1 : _recipe.baseServings;
    
    // Immediately fetch full details
    _scrollController.addListener(_scrollListener);
    _authorPageController = PageController(viewportFraction: 0.6);
    _authorPageController.addListener(() {
      if (mounted) setState(() => _authorPage = _authorPageController.page ?? 0.0);
    });
    _loadFullDetails();
    _checkBookmarkStatus();
    _checkLikeStatus();
    _checkDownloadStatus();
    _loadSubscriptionInfo();

    // Track popularity
    print("[RecipeDetails] Tracking view for: ${_recipe.id}");
    try {
      _recipeService.incrementRecipeView(_recipe.id);
    } catch (_) {}
    try {
      _recipeService.trackUserView(
        _recipe.id,
        recipe: _recipe,
        authorId: _recipe.authorId,
        tags: _recipe.tags,
      );
    } catch (_) {}
  }

  Future<void> _loadSubscriptionInfo() async {
    final sub = SubscriptionService();
    final remaining = await sub.getRemainingDownloads();
    final premium = await sub.canUsePremiumFeature();
    if (mounted) {
      setState(() {
        _remainingDownloads = remaining;
        _isPremium = premium;
      });
    }
  }

  void _scrollListener() {
    if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
      if (_fabExpanded) setState(() => _fabExpanded = false);
    } else if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
      if (!_fabExpanded) setState(() => _fabExpanded = true);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _authorPageController.dispose();
    super.dispose();
  }

  Future<void> _refreshAfterReviews() async {
    try {
      final docId = _recipe.id.toString();
      final doc = await FirebaseFirestore.instance.collection('recipes').doc(docId).get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _recipe = _recipe.copyWith(
            avgRating: double.tryParse(data['avg_rating']?.toString() ?? "0") ?? _recipe.avgRating,
            reviewCount: int.tryParse(data['review_count']?.toString() ?? "0") ?? _recipe.reviewCount,
          );
        });
      }
    } catch (_) {}
  }

  Future<void> _checkBookmarkStatus() async {
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (e) {
      // Firebase not initialized in tests
      return;
    }
    if (user == null) return;
    
    try {
      final isBookmarked = await _recipeService.isRecipeBookmarked(user.uid, _recipe.id);
      if (mounted) {
        setState(() => _bookmarked = isBookmarked);
      }
    } catch (e) {
      print("Error checking bookmark status: $e");
    }
  }

  Future<void> _checkLikeStatus() async {
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (e) {
      return;
    }
    if (user == null) return;
    
    try {
      final isLiked = await _recipeService.isRecipeLiked(user.uid, _recipe.id);
      if (mounted) {
        setState(() => _liked = isLiked);
      }
    } catch (e) {
      print("Error checking like status: $e");
    }
  }

  Future<void> _checkDownloadStatus() async {
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (e) {
      return;
    }
    if (user == null) return;

    try {
      final isOffline = await _localService.isRecipeOffline(_recipe.id, user.uid);
      if (mounted) {
        setState(() => _isDownloaded = isOffline);
      }
    } catch (e) {
      print("Error checking download status: $e");
    }
  }

  Future<void> _loadFullDetails() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      // 1. Try Firestore first (handles user-uploaded recipes reliably)
      try {
        final firestoreRecipe = await _recipeService.getRecipeById(_recipe.id).timeout(const Duration(seconds: 3));
        if (firestoreRecipe != null) {
          // --- 🛡️ ACCESS CONTROL: Nutritionist Recipe Check ---
          if (firestoreRecipe.isNutritionistRecipe) {
            final hasAccess = await SubscriptionService().hasNutritionistAccess(firestoreRecipe.authorId);
            if (!hasAccess && mounted) {
              _showRestrictedAccess(firestoreRecipe.authorId);
              return;
            }
          }

          final count = await _recipeService.countRecipesByAuthor(firestoreRecipe.authorId).timeout(const Duration(seconds: 3));
            
            if (mounted) {
              setState(() {
                _recipe = firestoreRecipe;
                _authorRecipeCount = count;
                _servings = (firestoreRecipe.baseServings <= 0) ? 1 : firestoreRecipe.baseServings;
                _loading = false;
              });
              
              if (firestoreRecipe.authorName != null && firestoreRecipe.authorName!.isNotEmpty) {
                final otherRecipes = await api.searchRecipes(firestoreRecipe.authorName!, limit: 12);
                if (mounted) {
                  setState(() {
                    _authorRecipes = otherRecipes.where((r) => r.id != _recipe.id && (r.authorId.isEmpty || r.authorId == firestoreRecipe.authorId)).toList();
                  });
                }
              }
            }
            return;
          }
      } catch (fsErr) {
        print("[RecipeDetails] Firestore fetch failed: $fsErr. Trying API...");
        if (mounted) {
          setState(() {});
        }
      }

      // 2. Try API next (official recipes)
      try {
        final fullRecipe = await api.getRecipeById(_recipe.id);
        int count = 0;
        if (fullRecipe.authorId.isNotEmpty) {
          count = await api.countRecipesByAuthor(fullRecipe.authorId);
        }

        if (mounted) {
          setState(() {
            _recipe = fullRecipe;
            _authorRecipeCount = count;
            _servings = (fullRecipe.baseServings <= 0) ? 1 : fullRecipe.baseServings;
            _loading = false;
          });
        }

        // EXTRA: Firestore dynamic merge as non-blocking background update
        // Skip in widget tests to avoid pending timers from timeouts
        if (!_isUnderTest) {
          _recipeService.getRecipeById(_recipe.id).then((fsRecipe) {
            if (fsRecipe != null && mounted) {
              setState(() {
                _recipe = _recipe.copyWith(
                  avgRating: fsRecipe.avgRating,
                  reviewCount: fsRecipe.reviewCount,
                );
                if (fsRecipe.baseServings > 1) {
                  _servings = fsRecipe.baseServings;
                }
              });
            }
          }).catchError((_) {});
        }
        
        // Fetch Other Recipes by same author
        if (fullRecipe.authorId.isNotEmpty) {
          final otherRecipes = await api.fetchRecipesByAuthor(fullRecipe.authorId, limit: 12);
          if (mounted) {
            setState(() {
              _authorRecipes = otherRecipes.where((r) => r.id != _recipe.id && (r.authorId.isEmpty || r.authorId == fullRecipe.authorId)).toList();
            });
            print("[RecipeDetails] Loaded ${_authorRecipes.length} recipes for authorId: ${fullRecipe.authorId}");
          }
        } else if (fullRecipe.authorName != null && fullRecipe.authorName!.isNotEmpty) {
          final otherRecipes = await api.searchRecipes(fullRecipe.authorName!, limit: 12);
          if (mounted) {
            setState(() {
              _authorRecipes = otherRecipes.where((r) => r.id != _recipe.id && (r.authorId.isEmpty || (fullRecipe.authorId.isNotEmpty && r.authorId == fullRecipe.authorId))).toList();
            });
            print("[RecipeDetails] Fallback: Loaded ${_authorRecipes.length} recipes for authorName: ${fullRecipe.authorName}");
          }
        }
        return; // Success, exit
      } catch (apiError) {
        print("[RecipeDetails] API Fetch failed finally: $apiError.");
      }

      // 3. Fallback to Local Storage (if both Firestore and API fail)
      if (user != null) {
        final isOffline = await _localService.isRecipeOffline(_recipe.id, user.uid);
        if (isOffline) {
          final offlineRecipes = await _localService.getRecipesByIds([_recipe.id], user.uid);
          if (offlineRecipes.isNotEmpty && mounted) {
            setState(() {
              _recipe = offlineRecipes.first;
              _authorRecipeCount = 0;
              _servings = (_recipe.baseServings <= 0) ? 1 : _recipe.baseServings;
              _loading = false;
            });
            return;
          }
        }
      }

      if (mounted) {
        setState(() {
          // Gracefully show passed-in recipe instead of error
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      print("[RecipeDetails] General Error in _loadFullDetails: $e");
      if (mounted) {
        setState(() {
          _loading = false;
          _error = null;
        });
      }
    }
  }

  Future<void> _toggleDownload() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Toaster.show(context, 'Please login to download recipes', isError: true, atTop: false);
      return;
    }

    try {
      if (_isDownloaded) {
        // Show confirmation dialog before removing
        final bool? confirmRemoval = await GlassDialog.show<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: bgColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              "Recipe already downloaded",
              style: TextStyle(
                color: textColor,
                fontFamily: "Satoshi",
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text(
              "Would you like to remove it from local storage?",
              style: TextStyle(
                color: textColor,
                fontFamily: "Satoshi",
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  "Cancel",
                  style: TextStyle(
                    color: Colors.grey,
                    fontFamily: "Satoshi",
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  "Remove",
                  style: TextStyle(
                    color: orange,
                    fontWeight: FontWeight.bold,
                    fontFamily: "Satoshi",
                  ),
                ),
              ),
            ],
          ),
        );

        if (confirmRemoval == true) {
          await _localService.removeRecipeOffline(_recipe.id, user.uid);
          if (mounted) {
            setState(() => _isDownloaded = false);
            Toaster.show(context, 'Removed from offline cache', atTop: false);
          }
        }
      } else {
        // 🛡️ GATE: Check if download is allowed (Premium/Trial or remaining free slots)
        final subService = SubscriptionService();
        final allowed = await subService.trackDownload(_recipe.id);

        if (!allowed) {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PremiumPaywallScreen()),
            );
          }
          return;
        }

        await _localService.saveRecipeOffline(_recipe, user.uid);
        if (mounted) {
          setState(() => _isDownloaded = true);
          Toaster.show(context, 'Saved for offline use!', atTop: false);
        }
      }
    } catch (e) {
      print("Error toggling download: $e");
    }
  }


  void _incServings() => setState(() => _servings += 1);

  void _decServings() {
    if (_servings <= 1) return;
    setState(() => _servings -= 1);
  }

  double _scaleFactor() {
    final base = _recipe.baseServings;
    if (base <= 0) return 1.0;
    return _servings / base;
  }

  String _fmtQty(double qty) {
    final scaled = qty * _scaleFactor();
    if (scaled <= 0) return "";
    
    final int wholePart = scaled.floor();
    final double fractionPart = scaled - wholePart;
    
    // Define standard cooking fractions
    final List<Map<String, dynamic>> fractions = [
      {'val': 0.0, 'str': ""},
      {'val': 0.125, 'str': "1/8"},
      {'val': 0.25, 'str': "1/4"},
      {'val': 0.333, 'str': "1/3"},
      {'val': 0.375, 'str': "3/8"},
      {'val': 0.5, 'str': "1/2"},
      {'val': 0.625, 'str': "5/8"},
      {'val': 0.666, 'str': "2/3"},
      {'val': 0.75, 'str': "3/4"},
      {'val': 0.875, 'str': "7/8"},
      {'val': 1.0, 'str': "UP"}, // Special marker for rounding up
    ];

    double minDiff = 999.0;
    Map<String, dynamic> bestMatch = fractions.first;

    for (var f in fractions) {
      double diff = (fractionPart - f['val']).abs();
      if (diff < minDiff) {
        minDiff = diff;
        bestMatch = f;
      }
    }

    if (bestMatch['str'] == "UP") {
      return (wholePart + 1).toString();
    }
    
    if (bestMatch['val'] == 0.0) {
      return wholePart > 0 ? wholePart.toString() : "0";
    }

    return wholePart > 0 ? "$wholePart ${bestMatch['str']}" : bestMatch['str'];
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Background pattern
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30.sw),
              child: Stack(
                children: const [
                  Positioned.fill(child: ColoredBox(color: bgColor)),
                  Positioned.fill(child: PatternBackground()),
                ],
              ),
            ),
          ),

          // Main Layout: Header + Content
          SafeArea(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30.sw),
              child: _buildBodyState(context),
            ),
          ),
        ],
      ),

      floatingActionButton: AnimatedStartCookingFab(
        isExpandedManually: _fabExpanded,
        onTap: () {
          // SAFE NAVIGATION: Ensure we are not in a build phase
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;

            // 🛡️ GATE: Check subscription before opening cooking mode
            final subService = SubscriptionService();
            final hasAccess = await subService.canUseFeature('voice_cooking');

            if (!hasAccess && mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PremiumPaywallScreen()),
              );
              return;
            }

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CookingDetailsScreen(
                  recipe: _recipe,
                  initialServings: _servings,
                ),
              ),
            );
          });
        },
      ),
    );
  }

  Widget _buildBodyState(BuildContext context) {
    if (_loading) {
      return const RecipeSkeletonLoader();
    }

    if (_error == "RESTRICTED_ACCESS") {
      return _buildRestrictedUI(context);
    }

    if (_error != null) {
      return RecipeErrorState(
        message: _error!,
        onRetry: _loadFullDetails,
      );
    }

    // Column Layout: Fixed Header + Scrollable Content
    return Column(
      children: [
        _buildHeader(context),
        Expanded(
          child: _content(context, _recipe),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.sw, 20.sh, 20.sw, 10.sh),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back Button
          _iconTile(
            onTap: () {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                 if (mounted) Navigator.maybePop(context);
              });
            },
            child: Icon(Icons.arrow_back_ios_new, size: 18.sw, color: textColor),
          ),

          // Actions
          Row(
            children: [
              _iconTile(
                onTap: () async {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) return;
                  
                  setState(() => _liked = !_liked);
                  try {
                    await _recipeService.toggleRecipeLike(user.uid, _recipe.id);
                  } catch (e) {
                    setState(() => _liked = !_liked);
                  }
                },
                child: HeartBurst(
                  isLiked: _liked,
                  child: Icon(
                    _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: _liked ? Colors.red : textColor,
                    size: 22.sw,
                  ),
                ),
              ),
              SizedBox(width: 10.sw),
               _iconTile(
                onTap: () async {
                  await _toggleDownload();
                  _loadSubscriptionInfo(); // Refresh quota
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DownloadAnimatedIcon(
                      isDownloaded: _isDownloaded,
                      child: Icon(
                        _isDownloaded
                            ? Icons.download_done_rounded
                            : Icons.file_download_outlined,
                        color: _isDownloaded ? orange : textColor,
                        size: 22.sw,
                      ),
                    ),
                    if (!_isPremium && !_isDownloaded && _remainingDownloads > 0)
                      Padding(
                        padding: EdgeInsets.only(top: 2.sh),
                        child: Text(
                          "$_remainingDownloads/5",
                          style: TextStyle(
                            fontSize: 8.sp,
                            color: textColor.withValues(alpha: 0.6),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: 10.sw),
              _iconTile(
                onTap: () {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (context) => AddToCookbookBottomSheet(
                        recipe: _recipe,
                      ),
                    ).then((_) => _checkBookmarkStatus());
                  });
                },
                child: BookmarkAnimatedIcon(
                  isBookmarked: _bookmarked,
                  child: Icon(
                    _bookmarked
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: _bookmarked ? orange : textColor,
                    size: 22.sw,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }



  // --- REAL CONTENT ---
  Widget _content(BuildContext context, Recipe r) {
    final authorName = r.authorName ?? "Unknown";
    final ingredientCount = r.ingredients.length;

    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(18.sw, 10.sh, 18.sw, 90.sh),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StaggeredEntry(
            delay: 0,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AuthorProfileScreen(
                      authorId: r.authorId,
                      authorName: authorName,
                      profileImageUrl: r.authorProfileImageUrl,
                    ),
                  ),
                );
              },
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(50.sw),
                    child: _authorAvatar(r.authorProfileImageUrl),
                  ),
                  SizedBox(width: 12.sw),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authorName,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w800,
                            fontFamily: "Satoshi",
                          ),
                        ),
                        SizedBox(height: 2.sh),
                        Text(
                          "${_authorRecipeCount} Recipes",
                          style: TextStyle(
                            color: textColor,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            fontFamily: "Satoshi",
                          ),
                        ),
                      ],
                    ),
                  ),
                  _ratingPill(r.avgRating),
                ],
              ),
            ),
          ),

          SizedBox(height: 14.sh),

          // image with parallax
          StaggeredEntry(
            delay: 100,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20.sw),
              child: AspectRatio(
                aspectRatio: 331 / 209,
                child: AnimatedBuilder(
                  animation: _scrollController,
                  builder: (context, child) {
                    double offset = 0;
                    double scale = 1.1;
                    if (_scrollController.hasClients) {
                       offset = _scrollController.offset * 0.4; // More intense parallax
                       scale = 1.1 + (_scrollController.offset * 0.0002); // Subtle zoom on scroll
                    }
                    return Transform.translate(
                      offset: Offset(0, offset),
                      child: Transform.scale(
                        scale: scale, 
                        child: child,
                      ),
                    );
                  },
                  child: _netImage(
                    url: r.imageUrl,
                    fallback: Image.asset(
                      'assets/logos/recipe_placeholder.jpg',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ),

          SizedBox(height: 14.sh),

          // title + ingredients count
          StaggeredEntry(
            delay: 200,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    r.name,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w800,
                      fontFamily: "Satoshi",
                    ),
                  ),
                ),
                SizedBox(width: 10.sw),
                Text(
                  "$ingredientCount Ingredients",
                  style: TextStyle(
                    color: textColor,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                    fontFamily: "Satoshi",
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 12.sh),

          // time cards
          StaggeredEntry(
            delay: 300,
            child: _threeTimeCard(
              totalMin: r.minutes,
              prepMin: r.prepMinutes,
              cookMin: r.cookMinutes,
            ),
          ),

          SizedBox(height: 14.sh),

          // tips/photos button
          StaggeredEntry(
            delay: 400,
            child: InkWell(
              onTap: () {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReviewsScreen(recipe: r),
                    ),
                  ).then((_) => _refreshAfterReviews());
                });
              },
              borderRadius: BorderRadius.circular(20.sw),
              child: Container(
                width: double.infinity,
                height: 62.sh,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      textColor,
                      textColor.withValues(alpha: 0.85),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20.sw),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF462F4D).withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: EdgeInsets.symmetric(horizontal: 20.sw),
                child: Row(
                  children: [
                    Icon(Icons.star_outline_rounded, size: 22.sw, color: orange),
                    SizedBox(width: 14.sw),
                    Expanded(
                      child: Text(
                        "See all tips and Photos",
                        style: TextStyle(
                          color: const Color(0xFFFFF2EA),
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                          fontFamily: "Satoshi",
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded,
                        size: 14.sw, color: const Color(0xFFFFF2EA)),
                  ],
                ),
              ),
            ),
          ),

          SizedBox(height: 18.sh),

          // ingredients header + servings control
          StaggeredEntry(
            delay: 500,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Ingredients",
                      style: TextStyle(
                        color: textColor,
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w800,
                        fontFamily: "Satoshi",
                      ),
                    ),
                    SizedBox(height: 4.sh),
                    Container(
                      width: 60.sw,
                      height: 4.sh,
                      decoration: BoxDecoration(
                        color: orange,
                        borderRadius: BorderRadius.circular(2.sw),
                      ),
                    ),
                  ],
                ),
                _servingControl(),
              ],
            ),
          ),

          SizedBox(height: 10.sh),

          if (r.ingredients.isEmpty)
            Text(
              "No ingredients available.",
              style: TextStyle(
                color: textColor,
                fontSize: 13.sp,
                fontFamily: "Satoshi",
              ),
            )
          else
          StaggeredEntry(
            delay: 550,
            child: Column(
              children: r.ingredients.map((ing) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32.sw,
                          height: 32.sw,
                          decoration: BoxDecoration(
                            color: cardColor,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            IngredientIconMapper.getIcon(ing.name),
                            color: textColor,
                            size: 16.sw,
                          ),
                        ),
                        SizedBox(width: 12.sw),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ing.name,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: "Satoshi",
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          "${_fmtQty(ing.quantity)}${ing.unit.isEmpty ? "" : " ${ing.unit}"}",
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800,
                            fontFamily: "Satoshi",
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10.sh),
                    Divider(color: textColor.withValues(alpha:0.12), height: 1.sh),
                    SizedBox(height: 10.sh),
                  ],
                );
              }).toList(),
            ),
          ),

          SizedBox(height: 22.sh),

          // nutrition header
          StaggeredEntry(
            delay: 600,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Nutrition Info",
                        style: TextStyle(
                          color: textColor,
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w800,
                          fontFamily: "Satoshi",
                        ),
                      ),
                      Text(
                        "scaled for $_servings ${_servings > 1 ? 'servings' : 'serving'}",
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.5),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          fontFamily: "Satoshi",
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.sw),
                InkWell(
                  onTap: () =>
                      setState(() => _nutritionExpanded = !_nutritionExpanded),
                  child: Row(
                    children: [
                      Text(
                        "View Info",
                        style: TextStyle(
                          color: orange2,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                          fontFamily: "Satoshi",
                        ),
                      ),
                      SizedBox(width: 6.sw),
                      Text(
                        _nutritionExpanded ? "−" : "+",
                        style: TextStyle(
                          color: orange2,
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w900,
                          fontFamily: "Satoshi",
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 10.sh),

          AnimatedSize(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            child: _nutritionExpanded 
              ? _nutritionBlock(r) 
              : const SizedBox(width: double.infinity, height: 0),
          ),

          SizedBox(height: 22.sh),

          StaggeredEntry(
            delay: 650,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Cooking Directions",
                  style: TextStyle(
                    color: textColor,
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w800,
                    fontFamily: "Satoshi",
                  ),
                ),
                SizedBox(height: 4.sh),
                Container(
                  width: 40.sw,
                  height: 4.sh,
                  decoration: BoxDecoration(
                    color: orange,
                    borderRadius: BorderRadius.circular(2.sw),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 10.sh),

          if (r.directions.isEmpty)
            StaggeredEntry(
              delay: 700,
              child: Text(
                "No directions available.",
                style: TextStyle(
                  color: textColor,
                  fontSize: 13.sp,
                  fontFamily: "Satoshi",
                ),
              ),
            )
          else
            StaggeredEntry(
              delay: 700,
              child: Column(
                children: List.generate(
                  (r.stepsDetailed != null && r.stepsDetailed!.isNotEmpty)
                      ? r.stepsDetailed!.length
                      : r.directions.length,
                  (i) {
                    String text = "";
                    String? stepImageUrl;

                    if (r.stepsDetailed != null && r.stepsDetailed!.length > i) {
                      final detail = r.stepsDetailed![i];
                      text = detail['text'] ?? "";
                      stepImageUrl = detail['imageUrl'];
                    } else if (r.directions.length > i) {
                      text = r.directions[i];
                    }

                    return Container(
                      width: double.infinity,
                      margin: EdgeInsets.only(bottom: 12.sh),
                      padding: EdgeInsets.all(12.sw),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(15.sw),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(top: 2.sh),
                                child: Text(
                                  "${i + 1}.",
                                  style: TextStyle(
                                    color: orange,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: "Satoshi",
                                  ),
                                ),
                              ),
                              SizedBox(width: 12.sw),
                              Expanded(
                                child: Text(
                                  text,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: "Satoshi",
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (stepImageUrl != null && stepImageUrl.isNotEmpty) ...[
                            SizedBox(height: 12.sh),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10.sw),
                              child: Image.network(
                                stepImageUrl,
                                width: double.infinity,
                                height: 200.sh,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return Container(
                                    width: double.infinity,
                                    height: 200.sh,
                                    color: Colors.black12,
                                    child: const Center(child: CircularProgressIndicator()),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

          if (_authorRecipes.isNotEmpty) ...[
            SizedBox(height: 32.sh),
            StaggeredEntry(
              delay: 750,
              child: GestureDetector(
                onTap: () {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AuthorProfileScreen(
                          authorId: r.authorId,
                          authorName: authorName,
                          profileImageUrl: r.authorProfileImageUrl,
                        ),
                      ),
                    );
                  });
                },
                child: Row(
                  children: [
                    Text(
                      "More from Author",
                      style: TextStyle(
                        color: textColor,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w800,
                        fontFamily: "Satoshi",
                      ),
                    ),
                    const Spacer(),
                    Text(
                      "See all",
                      style: TextStyle(
                        color: orange,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        fontFamily: "Satoshi",
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 14.sh),
            StaggeredEntry(
              delay: 800,
              child: SizedBox(
                height: 200.sh,
                child: PageView.builder(
                  controller: _authorPageController,
                  padEnds: false,
                  itemCount: _authorRecipes.length,
                  itemBuilder: (context, index) {
                    final ar = _authorRecipes[index];
                    final double diff = (index - _authorPage).abs();
                    final double scale = (1.0 - (diff * 0.15)).clamp(0.85, 1.0);
                    final double opacity = (1.0 - (diff * 0.3)).clamp(0.5, 1.0);

                    return Transform.scale(
                      scale: scale,
                      child: Opacity(
                        opacity: opacity,
                        child: GestureDetector(
                          onTap: () {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RecipeDetailsScreen(recipe: ar),
                                ),
                              );
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(20.sw),
                              boxShadow: [
                                BoxShadow(
                                  color: textColor.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.vertical(top: Radius.circular(20.sw)),
                                          child: _netImage(
                                            url: ar.imageUrl,
                                            fallback: Image.asset('assets/logos/recipe_placeholder.jpg', fit: BoxFit.cover),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        right: 8.sw,
                                        top: 8.sw,
                                        child: Container(
                                          padding: EdgeInsets.symmetric(horizontal: 8.sw, vertical: 4.sh),
                                          decoration: BoxDecoration(
                                            color: Colors.black54,
                                            borderRadius: BorderRadius.circular(10.sw),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.schedule_rounded, color: Colors.white, size: 10.sw),
                                              SizedBox(width: 4.sw),
                                              Text(
                                                "${ar.minutes} min",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10.sp,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.all(10.sw),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ar.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w800,
                                          fontFamily: "Satoshi",
                                        ),
                                      ),
                                      SizedBox(height: 4.sh),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          RecipeRatingWidget(
                                            recipeId: ar.id,
                                            initialRating: ar.avgRating,
                                            style: TextStyle(
                                              color: textColor.withValues(alpha: 0.7),
                                              fontSize: 10.sp,
                                              fontFamily: "Satoshi",
                                            ),
                                          ),
                                          Text(
                                            ar.difficulty ?? "Easy",
                                            style: TextStyle(
                                              color: orange,
                                              fontSize: 10.sp,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
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
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _iconTile({required VoidCallback onTap, required Widget child}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50.sw,
        height: 50.sw,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(15.sw),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  Widget _authorAvatar(String? url) {
    return _netImage(
      url: url,
      w: 42.sw,
      h: 42.sw,
      fallback: Container(
        width: 42.sw,
        height: 42.sw,
        decoration: BoxDecoration(
          color: cardColor,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.person, size: 24.sw, color: orange),
      ),
    );
  }

  Widget _netImage({
    required String? url,
    double? w,
    double? h,
    required Widget fallback,
  }) {
    if (url == null || url.trim().isEmpty) return fallback;

    return Image.network(
      url,
      width: w,
      height: h,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          width: w,
          height: h,
          color: cardColor,
          alignment: Alignment.center,
          child: SizedBox(
            width: 20.sw,
            height: 20.sw,
            child: CircularProgressIndicator(strokeWidth: 2.sw),
          ),
        );
      },
      errorBuilder: (_, __, ___) => fallback,
    );
  }

  Widget _ratingPill(double rating) {
    final bool hasRating = rating > 0;
    
    // Format to 2 decimal places but remove trailing zeros (e.g. 4.00 -> 4, 4.25 -> 4.25)
    String ratingText = "no rating";
    if (hasRating) {
      ratingText = rating.toStringAsFixed(2).replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '');
    }

    return Container(
      height: 34.sh,
      padding: EdgeInsets.symmetric(horizontal: 10.sw),
      decoration: BoxDecoration(
        color: hasRating ? orange2 : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10.sw),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasRating) ...[
            Icon(Icons.star_rounded, size: 18.sw, color: Colors.white),
            SizedBox(width: 6.sw),
          ],
          Text(
            ratingText,
            style: TextStyle(
              color: hasRating ? Colors.white : textColor.withValues(alpha: 0.5),
              fontSize: 12.sp,
              fontWeight: FontWeight.w900,
              fontFamily: "Satoshi",
            ),
          ),
        ],
      ),
    );
  }

  Widget _servingControl() {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.sw, vertical: 8.sh),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(10.sw),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _orangeMiniBtn(icon: Icons.remove, onTap: _decServings),
            SizedBox(width: 10.sw),
            Text(
              "$_servings Serving",
              style: TextStyle(
                color: textColor,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                fontFamily: "Satoshi",
              ),
            ),
            SizedBox(width: 10.sw),
            _orangeMiniBtn(icon: Icons.add, onTap: _incServings),
          ],
        ),
      ),
    );
  }

  Widget _orangeMiniBtn({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.sw),
      child: Container(
        width: 26.sw,
        height: 26.sw,
        decoration: BoxDecoration(
          color: orange,
          borderRadius: BorderRadius.circular(8.sw),
        ),
        child: Icon(icon, size: 16.sw, color: Colors.white),
      ),
    );
  }

  Widget _nutritionBlock(Recipe r) {
    final n = r.getScaledNutrition(_servings) ?? r.nutrition;
    if (n == null || n.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(14.sw),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12.sw),
        ),
        child: Text(
          "No nutrition info available.",
          style: TextStyle(
            color: textColor,
            fontSize: 13.sp,
            fontFamily: "Satoshi",
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.sw),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12.sw),
      ),
      child: Column(
        children: n.entries.map((e) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 8.sh),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    e.key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      fontFamily: "Satoshi",
                    ),
                  ),
                ),
                SizedBox(width: 8.sw),
                Expanded(
                  flex: 2,
                  child: Text(
                    e.value,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      fontFamily: "Satoshi",
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _threeTimeCard({
    required int totalMin,
    int? prepMin,
    int? cookMin,
  }) {
    final prep = (prepMin == null || prepMin <= 0) ? "—" : "$prepMin min";
    final cook = (cookMin == null || cookMin <= 0) ? "—" : "$cookMin min";

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.sw, vertical: 14.sh),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20.sw),
      ),
      child: Row(
        children: [
          Expanded(
            child: _timeCol(Icons.schedule_rounded, "Total", "$totalMin min"),
          ),
          Container(width: 1.sw, height: 30.sh, color: textColor.withValues(alpha: 0.1)),
          Expanded(
            child: _timeCol(Icons.restaurant_rounded, "Prep", prep),
          ),
          Container(width: 1.sw, height: 30.sh, color: textColor.withValues(alpha: 0.1)),
          Expanded(
            child: _timeCol(Icons.local_fire_department_rounded, "Cook", cook),
          ),
        ],
      ),
    );
  }

  Widget _timeCol(IconData icon, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 28.sw,
          height: 28.sw,
          decoration: const BoxDecoration(
            color: orange,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 14.sw),
        ),
        SizedBox(width: 6.sw),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.6),
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w800,
                  fontFamily: "Satoshi",
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                value,
                style: TextStyle(
                  color: textColor,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w900,
                  fontFamily: "Satoshi",
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metricTile(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.6),
                  fontSize: 12.sp,
                  fontFamily: "Satoshi",
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: textColor,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  fontFamily: "Satoshi",
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showRestrictedAccess(String authorId) async {
    if (!mounted) return;
    try {
      final authorDoc = await FirebaseFirestore.instance.collection('nutritionists').doc(authorId).get();
      if (!authorDoc.exists) {
        if (mounted) setState(() { _loading = false; _error = "Expert profile not found."; });
        return;
      }
      final authorData = authorDoc.data()!;
      if (mounted) {
        setState(() { _loading = false; _error = "RESTRICTED_ACCESS"; });
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TierComparisonScreen(
              nutritionistId: authorId,
              nutritionistData: authorData,
              currentTier: 0,
            ),
          ),
        );
        if (result == "refresh" && mounted) _loadFullDetails();
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = "Failed to verify access permissions."; });
    }
  }

  Widget _buildRestrictedUI(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(30.sw),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20.sw),
              decoration: BoxDecoration(color: orange.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(Icons.lock_person_rounded, color: orange, size: 60.sw),
            ),
            SizedBox(height: 24.sh),
            Text("Exclusive Recipe", style: TextStyle(color: textColor, fontSize: 24.sp, fontWeight: FontWeight.w900, fontFamily: "Satoshi")),
            SizedBox(height: 12.sh),
            Text("This professional recipe is only available to subscribers of ${_recipe.authorName ?? 'this expert'}.",
              textAlign: TextAlign.center, style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 15.sp, fontFamily: "Satoshi", height: 1.5)),
            SizedBox(height: 40.sh),
            ElevatedButton(
              onPressed: () => _loadFullDetails(),
              style: ElevatedButton.styleFrom(
                backgroundColor: orange, foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32.sw, vertical: 16.sh),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.sw)),
              ),
              child: Text("Check Access / Subscribe", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp)),
            ),
            SizedBox(height: 12.sh),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Go Back", style: TextStyle(color: textColor.withValues(alpha: 0.5), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}