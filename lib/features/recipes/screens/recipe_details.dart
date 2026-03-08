import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_api_service.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/core/widgets/skeletons.dart';
import 'cooking_details.dart';
import 'package:hidden_pantry_app/core/constants/api_constants.dart';
import 'package:hidden_pantry_app/features/recipes/screens/reviews/reviews.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_service.dart';
import 'package:hidden_pantry_app/features/recipes/services/local_recipe_service.dart';
import 'package:hidden_pantry_app/core/widgets/add_to_cookbook_bottom_sheet.dart';
import 'author_profile.dart';
import 'package:hidden_pantry_app/features/recipes/widgets/recipe_rating_widget.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';

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

  int _servings = 1;
  bool _nutritionExpanded = false;

  late final RecipeService _recipeService;
  final LocalRecipeService _localService = LocalRecipeService();

  @override
  void initState() {
    super.initState();
    api = widget.apiService ?? const RecipeApiService(baseUrl: ApiConstants.baseUrl);
    _recipeService = widget.recipeService ?? RecipeService();

    // Start with passed recipe
    _recipe = widget.recipe;
    _servings = (_recipe.baseServings <= 0) ? 1 : _recipe.baseServings;
    
    // Immediately fetch full details
    _loadFullDetails();
    _checkBookmarkStatus();
    _checkLikeStatus();
    _checkDownloadStatus();

    // Track popularity
    print("[RecipeDetails] Tracking view for: ${_recipe.id}");
    _recipeService.incrementRecipeView(_recipe.id);
    _recipeService.trackUserView(
      _recipe.id,
      recipe: _recipe,
      authorId: _recipe.authorId,
      tags: _recipe.tags,
    );
  }

  Future<void> _refreshAfterReviews() async {
    try {
      final firestoreRecipe = await _recipeService.getRecipeById(_recipe.id).timeout(const Duration(seconds: 5));
      if (firestoreRecipe != null && mounted) {
        setState(() {
          _recipe = _recipe.copyWith(
            avgRating: firestoreRecipe.avgRating,
            reviewCount: firestoreRecipe.reviewCount,
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

    try {
      // 1. Try Firestore first (handles user-uploaded recipes reliably)
      try {
        final firestoreRecipe = await _recipeService.getRecipeById(_recipe.id).timeout(const Duration(seconds: 5));
        if (firestoreRecipe != null) {
          final bool isPartial = firestoreRecipe.name.isEmpty || firestoreRecipe.directions.isEmpty;
          if (!isPartial) {
            final count = await _recipeService.countRecipesByAuthor(firestoreRecipe.authorId).timeout(const Duration(seconds: 5));
            
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
      final user = FirebaseAuth.instance.currentUser;
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
      Toaster.show(context, 'Please login to download recipes', isError: true);
      return;
    }

    try {
      if (_isDownloaded) {
        // Show confirmation dialog before removing
        final bool? confirmRemoval = await showDialog<bool>(
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
            Toaster.show(context, 'Removed from offline cache');
          }
        }
      } else {
        await _localService.saveRecipeOffline(_recipe, user.uid);
        if (mounted) {
          setState(() => _isDownloaded = true);
          Toaster.show(context, 'Saved for offline use!');
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
    
    // Check for whole numbers
    if ((scaled - scaled.roundToDouble()).abs() < 0.0001) {
      return scaled.round().toString();
    }
    
    // Split into whole and fractional parts
    final int wholePart = scaled.floor();
    final double fractionPart = scaled - wholePart;
    
    // Fraction lookup table for common cooking decimals
    String? fraction;
    if ((fractionPart - 0.5).abs() < 0.02) fraction = "1/2";
    else if ((fractionPart - 0.25).abs() < 0.02) fraction = "1/4";
    else if ((fractionPart - 0.75).abs() < 0.02) fraction = "3/4";
    else if ((fractionPart - 0.33).abs() < 0.04) fraction = "1/3";
    else if ((fractionPart - 0.66).abs() < 0.04) fraction = "2/3";
    else if ((fractionPart - 0.125).abs() < 0.02) fraction = "1/8";
    else if ((fractionPart - 0.375).abs() < 0.02) fraction = "3/8";
    else if ((fractionPart - 0.625).abs() < 0.02) fraction = "5/8";
    else if ((fractionPart - 0.875).abs() < 0.02) fraction = "7/8";

    if (fraction != null) {
      return wholePart > 0 ? "$wholePart $fraction" : fraction;
    }

    // Fallback to decimal if no common fraction match
    return scaled
        .toStringAsFixed(2)
        .replaceAll(RegExp(r"0+$"), "")
        .replaceAll(RegExp(r"\.$"), "");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Background pattern
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
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
              borderRadius: BorderRadius.circular(30),
              child: _buildBodyState(context),
            ),
          ),
        ],
      ),

      // Sticky CTA stays
      bottomNavigationBar: _StickyStartCooking(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CookingDetailsScreen(
                recipe: _recipe,
                initialServings: _servings,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBodyState(BuildContext context) {
    if (_loading) {
      return const _SkeletonLoader();
    }

    if (_error != null) {
      return _ErrorState(
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
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back Button
          _iconTile(
            onTap: () => Navigator.maybePop(context),
            child: const Icon(Icons.arrow_back_ios_new, size: 18, color: textColor),
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
                child: Icon(
                  _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: _liked ? Colors.red : textColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              _iconTile(
                onTap: _toggleDownload,
                child: Icon(
                  _isDownloaded ? Icons.download_done_rounded : Icons.file_download_outlined,
                  color: _isDownloaded ? orange : textColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              _iconTile(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (context) => AddToCookbookBottomSheet(
                      recipe: _recipe,
                    ),
                  ).then((_) => _checkBookmarkStatus());
                },
                child: Icon(
                  _bookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: _bookmarked ? orange : textColor,
                  size: 22,
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
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 18),

          const SizedBox(height: 18),

          GestureDetector(
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
                  borderRadius: BorderRadius.circular(50),
                  child: _authorAvatar(r.authorProfileImageUrl),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authorName,
                        style: const TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          fontFamily: "Satoshi",
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${_authorRecipeCount} Recipes",
                        style: const TextStyle(
                          color: textColor,
                          fontSize: 12,
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

          const SizedBox(height: 14),

          // image
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 331 / 209,
              child: _netImage(
                url: r.imageUrl,
                fallback: Image.asset(
                  'assets/Logos/recipe_placeholder.jpg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // title + ingredients count
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  r.name,
                  style: const TextStyle(
                    color: textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    fontFamily: "Satoshi",
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "$ingredientCount Ingredients",
                style: const TextStyle(
                  color: textColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  fontFamily: "Satoshi",
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // time cards
          _threeTimeCard(
            totalMin: r.minutes,
            prepMin: r.prepMinutes,
            cookMin: r.cookMinutes,
          ),

          const SizedBox(height: 14),

          // tips/photos button
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReviewsScreen(recipe: r),
                ),
              ).then((_) => _refreshAfterReviews());
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: double.infinity,
              height: 62,
              decoration: BoxDecoration(
                border: Border.all(color: orange, width: 1.2),
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: const [
                  Expanded(
                    child: Text(
                      "See all tips and Photos",
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontFamily: "Satoshi",
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 16, color: textColor),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),

          // ingredients header + servings control
          Row(
            children: [
              const Text(
                "Ingredients",
                style: TextStyle(
                  color: textColor,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  fontFamily: "Satoshi",
                ),
              ),
              const Spacer(),
              _servingControl(),
            ],
          ),

          const SizedBox(height: 10),

          if (r.ingredients.isEmpty)
            const Text(
              "No ingredients available.",
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontFamily: "Satoshi",
              ),
            )
          else
            Column(
              children: r.ingredients.map((ing) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ing.name,
                                style: const TextStyle(
                                  color: textColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: "Satoshi",
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          "${_fmtQty(ing.quantity)}${ing.unit.isEmpty ? "" : " ${ing.unit}"}",
                          style: const TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            fontFamily: "Satoshi",
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Divider(color: textColor.withValues(alpha:0.12), height: 1),
                    const SizedBox(height: 10),
                  ],
                );
              }).toList(),
            ),

          const SizedBox(height: 22),

          // nutrition header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Nutrition Info",
                      style: TextStyle(
                        color: textColor,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        fontFamily: "Satoshi",
                      ),
                    ),
                    Text(
                      "scaled for $_servings ${_servings > 1 ? 'servings' : 'serving'}",
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        fontFamily: "Satoshi",
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () =>
                    setState(() => _nutritionExpanded = !_nutritionExpanded),
                child: Row(
                  children: [
                    const Text(
                      "View Info",
                      style: TextStyle(
                        color: orange2,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        fontFamily: "Satoshi",
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _nutritionExpanded ? "−" : "+",
                      style: const TextStyle(
                        color: orange2,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        fontFamily: "Satoshi",
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          if (_nutritionExpanded) _nutritionBlock(r),

          const SizedBox(height: 22),

          const Text(
            "Directions",
            style: TextStyle(
              color: textColor,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              fontFamily: "Satoshi",
            ),
          ),

          const SizedBox(height: 10),

          if (r.directions.isEmpty)
            const Text(
              "No directions available.",
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontFamily: "Satoshi",
              ),
            )
          else
            Column(
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
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: orange.withValues(alpha:0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  "${i + 1}",
                                  style: const TextStyle(
                                    color: orange,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: "Satoshi",
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                text,
                                style: const TextStyle(
                                  color: textColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: "Satoshi",
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (stepImageUrl != null && stepImageUrl.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              stepImageUrl,
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return Container(
                                  width: double.infinity,
                                  height: 200,
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

          if (_authorRecipes.isNotEmpty) ...[
            const SizedBox(height: 32),
            GestureDetector(
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
                  const Text(
                    "More from Author",
                    style: TextStyle(
                      color: textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      fontFamily: "Satoshi",
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    "See all",
                    style: TextStyle(
                      color: orange,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: "Satoshi",
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _authorRecipes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final ar = _authorRecipes[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RecipeDetailsScreen(recipe: ar),
                        ),
                      );
                    },
                    child: Container(
                      width: 140,
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: _netImage(
                                url: ar.imageUrl,
                                fallback: Image.asset('assets/Logos/recipe_placeholder.jpg', fit: BoxFit.cover),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ar.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: textColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: "Satoshi",
                                  ),
                                ),
                                const SizedBox(height: 2),
                                RecipeRatingWidget(
                                  recipeId: ar.id,
                                  initialRating: ar.avgRating,
                                  style: const TextStyle(
                                    color: textColor,
                                    fontSize: 10,
                                    fontFamily: "Satoshi",
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
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
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(15),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  Widget _authorAvatar(String? url) {
    return _netImage(
      url: url,
      w: 42,
      h: 42,
      fallback: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: cardColor,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.person, size: 24, color: orange),
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
          child: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      errorBuilder: (_, __, ___) => fallback,
    );
  }

  Widget _ratingPill(double rating) {
    final bool hasRating = rating > 0;
    
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: hasRating ? orange2 : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasRating) ...[
            const Icon(Icons.star_rounded, size: 18, color: Colors.white),
            const SizedBox(width: 6),
          ],
          Text(
            hasRating ? rating.toStringAsFixed(1) : "no rating",
            style: TextStyle(
              color: hasRating ? Colors.white : textColor.withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              fontFamily: "Satoshi",
            ),
          ),
        ],
      ),
    );
  }

  Widget _servingControl() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _orangeMiniBtn(icon: Icons.remove, onTap: _decServings),
          const SizedBox(width: 10),
          Text(
            "$_servings Serving",
            style: const TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: "Satoshi",
            ),
          ),
          const SizedBox(width: 10),
          _orangeMiniBtn(icon: Icons.add, onTap: _incServings),
        ],
      ),
    );
  }

  Widget _orangeMiniBtn({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: orange,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }

  Widget _nutritionBlock(Recipe r) {
    final n = r.getScaledNutrition(_servings) ?? r.nutrition;
    if (n == null || n.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          "No nutrition info available.",
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontFamily: "Satoshi",
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: n.entries.map((e) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    e.key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      fontFamily: "Satoshi",
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Text(
                    e.value,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: textColor,
                      fontSize: 14,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: _timeCol("Total Time", "$totalMin min"),
          ),
          Expanded(
            child: _timeCol("Prep Time", prep),
          ),
          Expanded(
            child: _timeCol("Cook Time", cook),
          ),
        ],
      ),
    );
  }

  Widget _timeCol(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            fontFamily: "Satoshi",
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: orange,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            fontFamily: "Satoshi",
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

 

class _StickyStartCooking extends StatelessWidget {
  static const Color orange = Color(0xFFEF8A54);
  final VoidCallback onTap;

  const _StickyStartCooking({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 86, // keeps body from becoming 0
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end, // pinned right
            children: [
              InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  height: 56,
                  width: 190,
                  decoration: BoxDecoration(
                    color: orange,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          "Start Cooking",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            fontFamily: "Satoshi",
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Image.asset(
                        'assets/icons/next_filled.png',
                        width: 9,
                        height: 7,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _SkeletonLoader extends StatelessWidget {
  const _SkeletonLoader();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           // Debug text to prove visibility
           const Center(child: Text("Loading Recipe...", style: TextStyle(color: Colors.grey))),
           const SizedBox(height: 10),

           // Top Bar
           Row(children: const [
             SkeletonBox(width: 50, height: 50, borderRadius: BorderRadius.all(Radius.circular(15))),
             Spacer(),
             SkeletonBox(width: 50, height: 50, borderRadius: BorderRadius.all(Radius.circular(15))),
             SizedBox(width: 10),
             SkeletonBox(width: 50, height: 50, borderRadius: BorderRadius.all(Radius.circular(15))),
           ]),
           const SizedBox(height: 18),
           // Author Row
           Row(children: const [
             SkeletonBox(width: 42, height: 42, borderRadius: BorderRadius.all(Radius.circular(50))),
             SizedBox(width: 12),
             Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
               SkeletonBox(width: 100, height: 14),
               SizedBox(height: 6),
               SkeletonBox(width: 60, height: 10),
             ]),
             Spacer(),
             SkeletonBox(width: 60, height: 34, borderRadius: BorderRadius.all(Radius.circular(10))),
           ]),
           const SizedBox(height: 14),
           // Image
           const SkeletonBox(width: double.infinity, height: 210),
           const SizedBox(height: 14),
           // Title
           const SkeletonBox(width: 200, height: 28),
           const SizedBox(height: 12),
           // Time cards
           Row(children: const [
             Expanded(child: SkeletonBox(width: double.infinity, height: 60)),
             SizedBox(width: 10),
             Expanded(child: SkeletonBox(width: double.infinity, height: 60)),
             SizedBox(width: 10),
             Expanded(child: SkeletonBox(width: double.infinity, height: 60)),
           ]),
           const SizedBox(height: 20),
           // Ingredients
           const SkeletonBox(width: 150, height: 24),
           const SizedBox(height: 10),
           Column(
             children: List.generate(4, (i) => Padding(
               padding: const EdgeInsets.only(bottom: 10),
               child: Row(children: const [
                 Expanded(child: SkeletonBox(width: double.infinity, height: 16)),
                 SizedBox(width: 20),
                 SkeletonBox(width: 40, height: 16),
               ]),
             )),
           )
        ],
      ),
    );
  }
}
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 44, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              "Error: $message",
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF462F4D),
                fontSize: 13,
                fontFamily: "Satoshi",
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: onRetry,
              child: const Text("Retry"),
            ),
          ],
        ),
      ),
    );
  }
}
