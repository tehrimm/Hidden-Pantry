import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_api_service.dart';
import 'package:hidden_pantry_app/features/recipes/screens/recipe_details.dart';
import 'package:hidden_pantry_app/core/constants/api_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pantry_screen.dart';
import 'package:hidden_pantry_app/core/widgets/home_bottom_nav.dart';
import 'package:hidden_pantry_app/features/recipes/upload/upload_recipe_step1.dart';
import 'package:hidden_pantry_app/features/recipes/screens/saved_recipes.dart';
import 'package:hidden_pantry_app/features/nutritionist/screens/discovery.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_service.dart';
import 'filter_bottom_sheet.dart';
import 'package:hidden_pantry_app/features/recipes/widgets/recipe_card.dart';
import 'package:hidden_pantry_app/core/widgets/main_navigation_shell.dart';
import 'ingredient_camera_screen.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/widgets/skeletons.dart';
import 'package:hidden_pantry_app/features/user/services/subscription_service.dart';
import 'package:hidden_pantry_app/features/user/screens/premium_paywall_screen.dart';

import 'package:hidden_pantry_app/core/widgets/food_loader.dart';

class SearchScreen extends StatefulWidget {
  final bool inShell;
  final RecipeApiService? apiService;
  final bool openFilters;
  final String? initialQuery; // Added this
  const SearchScreen({
    super.key, 
    this.inShell = false, 
    this.apiService, 
    this.openFilters = false,
    this.initialQuery,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  late final RecipeApiService _api;
  
  Timer? _debounce;
  List<Recipe> _results = [];
  List<String> _recentSearches = [];
  List<String> _currentIngredients = [];
  List<String> _userAllergies = [];
  bool _hasSearched = false;
  bool _isSearching = false;
  int _limit = 20;
  bool _loadingMore = false;
  bool _hasMore = true;

  bool get _isUnderTest => widget.apiService != null;

  String? _suggestedQuery;
  int? _filterMaxMinutes;
  List<String> _filterTags = [];
  
  final FocusNode _searchFocus = FocusNode();

  final Color bg = const Color(0xFFFFF3EB);
  final Color purple = const Color(0xFF462F4D);
  final Color orange = const Color(0xFFEF8A54);

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    debugPrint('[SearchScreen] Initialized (inShell: ${widget.inShell})');
    _api = widget.apiService ?? const RecipeApiService(baseUrl: ApiConstants.baseUrl);
    _loadRecentSearches();
    _loadUserAllergies();
    _searchFocus.addListener(_onFocusChange);

    if (widget.openFilters) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openFilters();
      });
    }

    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _controller.text = widget.initialQuery!;
      _hasSearched = true;
      _saveSearch(widget.initialQuery!);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performSearch(widget.initialQuery!);
      });
    }
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  Future<void> _loadUserAllergies() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
         final snap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
         final data = snap.data();
         if (data != null && data['allergies'] is List) {
           setState(() {
             _userAllergies = List<String>.from(data['allergies']);
           });
           debugPrint('[SearchScreen] Loaded allergens: $_userAllergies');
         }
      }
    } catch (e) {
      debugPrint('[SearchScreen] Error loading allergens: $e');
    }
  }

  String get _historyKey {
    final user = FirebaseAuth.instance.currentUser;
    return user != null ? 'recent_searches_${user.uid}' : 'recent_searches';
  }

  Future<void> _loadRecentSearches() async {
    if (_isUnderTest) {
      setState(() => _recentSearches = []);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentSearches = prefs.getStringList(_historyKey) ?? [];
    });
  }

  Future<void> _saveSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    if (_isUnderTest) return;
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList(_historyKey) ?? [];
    
    history.remove(q);
    history.insert(0, q);
    
    if (history.length > 10) history = history.sublist(0, 10);
    
    await prefs.setStringList(_historyKey, history);
    setState(() => _recentSearches = history);
  }

  Future<void> _deleteSearch(String query) async {
    if (_isUnderTest) {
      setState(() => _recentSearches = _recentSearches.where((e) => e != query).toList());
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList(_historyKey) ?? [];
    history.remove(query);
    await prefs.setStringList(_historyKey, history);
    setState(() => _recentSearches = history);
  }

  Future<void> _clearHistory() async {
    if (_isUnderTest) {
      setState(() => _recentSearches = []);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    setState(() => _recentSearches = []);
  }

  void _onChanged(String query) {
    final q = query.trim();
    setState(() {
      _suggestedQuery = _getSuggestion(q);
      if (q.isEmpty) {
        _results = [];
        _loadRecentSearches();
        _suggestedQuery = null;
        _hasSearched = false;
      }
    });

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (q.isNotEmpty) {
      _debounce = Timer(const Duration(milliseconds: 500), () {
        _performSearch(q);
      });
    }
  }

  int _levenshtein(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var matrix = List.generate(a.length + 1, (i) => List.filled(b.length + 1, 0));
    for (var i = 0; i <= a.length; i++) matrix[i][0] = i;
    for (var j = 0; j <= b.length; j++) matrix[0][j] = j;
    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        var cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce(math.min);
      }
    }
    return matrix[a.length][b.length];
  }

  String? _getSuggestion(String query) {
    const knownKeywords = [
      "breakfast", "lunch", "dinner", "dessert", "snack", "soup", "salad", 
      "pasta", "seafood", "chicken", "beef", "mutton", "fish", "rice", "spicy", 
      "vegan", "vegetarian", "healthy", "smoothie", "drink", "cake", "cookie",
      "bread", "egg", "cheese", "tomato", "potato", "onion", "garlic", "baking",
      "italian", "mexican", "asian", "indian", "japanese", "chinese", "korean",
      "pancakes", "waffles", "burger", "pizza", "sandwich", "wrap", "curry"
    ];
    
    String? bestMatch;
    int bestDist = 3;
    final lowerQ = query.toLowerCase();
    
    if (lowerQ.length < 3) return null;
    
    for (var kw in knownKeywords) {
      int d = _levenshtein(lowerQ, kw);
      if (d < bestDist && d > 0) {
        bestDist = d;
        bestMatch = kw;
      }
    }
    return bestMatch;
  }

  List<Recipe> _applyAllergyFilter(List<Recipe> list) {
    if (list.isEmpty || _userAllergies.isEmpty) return list;

    final Map<String, List<String>> synonyms = {
      "dairy": ["milk", "cheese", "butter", "cream", "yogurt", "lactose", "whey", "casein", "ghee"],
      "tree nuts": ["almond", "walnut", "cashew", "pecan", "pistachio", "hazelnut", "brazil nut", "macadamia"],
      "shellfish": ["shrimp", "crab", "lobster", "mussel", "oyster", "scallop", "clam", "prawn"],
      "spicy": ["chili", "pepper", "jalapeno", "habanero", "cayenne", "sriracha", "hot sauce", "wasabi"],
      "gluten": ["wheat", "barley", "rye", "malt", "farro", "bulgur"],
      "eggs": ["egg", "yolk", "egg white", "albumin"],
    };

    return list.where((r) {
      final rName = r.name.toLowerCase();
      final rTags = r.tags.map((e) => e.toLowerCase()).toSet();
      final rAllergens = r.allergens.map((e) => e.toLowerCase()).toSet();
      final rIngredients = r.ingredients.map((e) => e.name.toLowerCase()).toList();

      for (final allergy in _userAllergies) {
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
    }).toList();
  }

  Future<void> _performSearch(String query, {bool isLoadMore = false}) async {
    if (!isLoadMore) {
      setState(() {
        _hasSearched = true;
        _isSearching = true;
        _hasMore = true;
        _limit = 20;
      });
    }

    List<Recipe> firestoreResults = [];
    List<Recipe> apiResults = [];

    try {
      if (!_isUnderTest) {
        firestoreResults = await RecipeService().searchRecipes(
          query,
          limit: _limit,
          ingredients: _currentIngredients,
          maxMinutes: _filterMaxMinutes,
          tags: _filterTags,
        );
      }
    } catch (e) {
      debugPrint('DEBUG _performSearch Firestore ERROR: $e');
    }

    try {
      apiResults = await _api.searchRecipes(
        query, 
        limit: _limit, 
        ingredients: _currentIngredients,
        maxMinutes: _filterMaxMinutes,
        tags: _filterTags,
        allergies: _userAllergies.isNotEmpty ? _userAllergies : null,
      );
    } catch (e) {
      debugPrint('DEBUG _performSearch API ERROR: $e');
    }

    if (mounted) {
      final List<Recipe> combined = [];
      if (firestoreResults.isNotEmpty) {
        combined.addAll(firestoreResults);
        for (var apiR in apiResults) {
          if (!combined.any((r) => r.id == apiR.id)) {
            combined.add(apiR);
          }
        }
      } else {
        combined.addAll(apiResults);
      }

      setState(() {
        _results = _applyAllergyFilter(combined);
        if (isLoadMore) _loadingMore = false;
        else _isSearching = false;

        if (apiResults.length < _limit) _hasMore = false;
      });
      FocusScope.of(context).unfocus();
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() {
      _loadingMore = true;
      _limit += 10;
    });
    await _performSearch(_controller.text, isLoadMore: true);
  }

  void _openRecipe(Recipe r) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RecipeDetailsScreen(
        recipe: r,
        apiService: _api,
      )),
    );
  }

  Future<void> _goToFullSearch() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    await _saveSearch(q);
    FocusScope.of(context).unfocus();
    await _performSearch(q);
  }

  Future<void> _openPantry() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantryScreen(
          initialSelectedIngredients: _currentIngredients,
          showSelectedSection: true,
        ),
      ),
    );

    if (result != null && result is List<String>) {
      setState(() {
        _currentIngredients = result;
      });
      final q = _controller.text.trim();
      if (_currentIngredients.isNotEmpty || q.isNotEmpty || _filterTags.isNotEmpty || _filterMaxMinutes != null) {
        _performSearch(q);
      } else {
        setState(() {
          _results = [];
          _hasSearched = false;
        });
      }
    }
  }

  Future<void> _openCamera() async {
    // 🛡️ GATE: Check subscription before opening camera
    final subService = SubscriptionService();
    final hasAccess = await subService.canUseFeature('image_recognition');

    if (!hasAccess) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PremiumPaywallScreen()),
        );
      }
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const IngredientCameraScreen()),
    );

    if (result != null && result is List<String>) {
      bool changed = false;
      for (var ingredient in result) {
        if (!_currentIngredients.contains(ingredient)) {
          _currentIngredients.add(ingredient);
          changed = true;
        }
      }
      
      if (changed) {
        setState(() {});
        _openPantry();
      }
    }
  }

  void _openFilters() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => FilterBottomSheet(
        initialMaxMinutes: _filterMaxMinutes,
        initialSelectedTags: _filterTags,
        onApply: (maxMinutes, tags) {
          setState(() {
            _filterMaxMinutes = maxMinutes;
            _filterTags = tags;
          });
          if (_controller.text.isNotEmpty || _currentIngredients.isNotEmpty || _filterTags.isNotEmpty || _filterMaxMinutes != null) {
             _performSearch(_controller.text);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.inShell ? Colors.transparent : bg,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          if (!widget.inShell) PatternBackground(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 36.sh),
                _searchBarRow(),
                if (_controller.text.isNotEmpty && _suggestedQuery != null) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Row(
                      children: [
                        Text("Did you mean: ", style: TextStyle(color: purple, fontFamily: "Satoshi")),
                        GestureDetector(
                          onTap: () {
                            final newQ = _suggestedQuery!;
                            _controller.text = newQ;
                            _controller.selection = TextSelection.fromPosition(TextPosition(offset: newQ.length));
                            setState(() {
                              _suggestedQuery = null;
                            });
                            if (_debounce?.isActive ?? false) _debounce!.cancel();
                            _performSearch(newQ);
                          },
                          child: Text(
                            '"$_suggestedQuery"',
                            style: TextStyle(
                              color: orange,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: "Satoshi",
                              decoration: TextDecoration.underline,
                              decorationColor: orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: (_controller.text.isNotEmpty || _currentIngredients.isNotEmpty) 
                    ? Column(
                        children: [
                          const SizedBox(height: 16),
                          _ingredientsFilterRow(),
                          const SizedBox(height: 16),
                        ],
                      )
                    : const SizedBox(width: double.infinity),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInQuad,
                    layoutBuilder: (child, List<Widget> previousChildren) {
                      return Stack(
                        children: [
                          ...previousChildren,
                          if (child != null) child,
                        ],
                      );
                    },
                    transitionBuilder: (child, animation) {
                      final slide = Tween<Offset>(
                        begin: const Offset(0, 0.05),
                        end: Offset.zero,
                      ).animate(animation);
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: slide,
                          child: child,
                        ),
                      );
                    },
                    child: (_controller.text.isEmpty && _currentIngredients.isEmpty && _results.isEmpty && !_hasSearched)
                        ? KeyedSubtree(
                            key: const ValueKey('recent_searches'),
                            child: _recentSearchesSection(),
                          )
                        : KeyedSubtree(
                            key: const ValueKey('results_list'),
                            child: _resultsList(),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: widget.inShell || _searchFocus.hasFocus 
          ? null 
          : HpBottomNav(
              currentIndex: 1,
              orange: orange,
              onTap: (index) {
                if (index == 1) return;
                if (index == 0) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => MainNavigationShell()),
                    (route) => false,
                  );
                } else if (index == 2) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const UploadRecipeStep1()));
                } else if (index == 3) {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SavedRecipesScreen()));
                } else if (index == 4) {
                   Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const NutritionistDiscoveryScreen())); 
                }
              },
            ),
    );
  }

  Widget _searchBarRow() {
    final bool isFocused = _searchFocus.hasFocus;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              height: 54,
              decoration: BoxDecoration(
                color: isFocused ? Colors.white : const Color(0xFFFDECE4),
                borderRadius: BorderRadius.circular(27),
                boxShadow: [
                  BoxShadow(
                    color: purple.withValues(alpha: isFocused ? 0.12 : 0.0),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: isFocused ? orange.withValues(alpha: 0.3) : Colors.transparent,
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (_searchFocus.hasFocus) {
                        _searchFocus.unfocus();
                      } else {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        } else {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => MainNavigationShell()),
                            (route) => false,
                          );
                        }
                      }
                    },
                    child: Icon(
                      isFocused ? Icons.close_rounded : Icons.arrow_back, 
                      size: 24, 
                      color: purple
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _searchFocus,
                      onChanged: _onChanged,
                      onSubmitted: (_) => _goToFullSearch(),
                      textInputAction: TextInputAction.search,
                      style: TextStyle(color: purple, fontSize: 16, fontFamily: "Satoshi"),
                      decoration: InputDecoration(
                        hintText: "Search Recipes",
                        hintStyle: TextStyle(color: purple.withValues(alpha:0.5), fontSize: 16, fontFamily: "Satoshi"),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _openCamera, 
                    child: Icon(Icons.camera_alt_outlined, size: 24, color: purple.withValues(alpha:0.7)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
            child: (_results.isEmpty && _controller.text.isEmpty && _currentIngredients.isEmpty && _filterTags.isEmpty && _filterMaxMinutes == null)
                ? GestureDetector(
                    key: const ValueKey('pantry_btn'),
                    onTap: _openPantry,
                    child: Image.asset(
                      'assets/food/pantry.png', 
                      width: 28,
                      height: 28,
                      errorBuilder: (_, __, ___) => Icon(Icons.shopping_bag, size: 30, color: purple),
                    ),
                  )
                : GestureDetector(
                    key: const ValueKey('filter_btn'),
                    onTap: _openFilters,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9E3D5),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          if (_filterTags.isNotEmpty || _filterMaxMinutes != null)
                            BoxShadow(
                              color: orange.withValues(alpha: 0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                        ]
                      ),
                      child: Icon(
                        Icons.tune_rounded, 
                        size: 24, 
                        color: _filterTags.isNotEmpty || _filterMaxMinutes != null ? orange : purple
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _ingredientsFilterRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: (_controller.text.isNotEmpty || _currentIngredients.isNotEmpty) ? 1.0 : 0.0,
        child: GestureDetector(
          onTap: _openPantry,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9E3D5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentIngredients.isNotEmpty 
                      ? "Ingredients (${_currentIngredients.length})"
                      : "Ingredients",
                  style: TextStyle(
                    color: purple,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    fontFamily: "Satoshi",
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.edit_outlined, size: 16, color: purple.withValues(alpha:0.6)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _resultsList() {
    if (_isSearching) {
      return Stack(
        children: [
          GridView.builder(
            padding: const EdgeInsets.all(22),
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 157 / 250,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: 4,
            itemBuilder: (_, i) => _StaggeredItem(index: i, child: _recipeCardSkeleton()),
          ),
          const Center(
            child: FoodLoader(size: 60),
          ),
        ],
      );
    }

    if (_results.isEmpty && (_controller.text.isNotEmpty || _hasSearched)) {
      final suggestion = _getSpellingSuggestion(_controller.text);
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "No recipes found",
              textAlign: TextAlign.center,
              style: TextStyle(color: purple.withValues(alpha:0.6), fontFamily: "Satoshi", fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              "Try removing some filters or check your spelling.",
              textAlign: TextAlign.center,
              style: TextStyle(color: purple.withValues(alpha:0.5), fontFamily: "Satoshi"),
            ),
            if (suggestion != null) ...[
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  _controller.text = suggestion;
                  _goToFullSearch();
                },
                child: Text(
                  "Did you mean '$suggestion'?",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFFEF8A54),
                    fontFamily: "Satoshi",
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                    decorationColor: const Color(0xFFEF8A54),
                  ),
                ),
              ),
            ]
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(22),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 157 / 250,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, i) {
                final r = _results[i];
                return _StaggeredItem(
                  index: i,
                  child: RecipeCard(
                    recipe: r,
                    onTap: () {
                      _saveSearch(r.name);
                      _openRecipe(r);
                    },
                  ),
                );
              },
              childCount: _results.length,
            ),
          ),
        ),
        if (_hasSearched && _hasMore && _results.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: _loadingMore
                    ? const SizedBox(
                        width: 40,
                        height: 40,
                        child: FoodLoader(size: 30),
                      )
                    : GestureDetector(
                        onTap: _loadMore,
                        child: Text(
                          "Load 10 more recipes",
                          style: TextStyle(
                            color: const Color(0xFFEF8A54),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: "Satoshi",
                            decoration: TextDecoration.underline,
                            decorationColor: const Color(0xFFEF8A54),
                          ),
                        ),
                      ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _recentSearchesSection() {
    if (_recentSearches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: purple.withValues(alpha:0.1)),
            const SizedBox(height: 16),
            Text(
              "No recent searches",
              style: TextStyle(color: purple.withValues(alpha:0.3), fontFamily: "Satoshi"),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Recent Searches",
              style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 18, fontFamily: "Satoshi"),
            ),
            GestureDetector(
              onTap: _clearHistory,
              child: Text(
                "Clear All",
                style: TextStyle(color: purple.withValues(alpha:0.5), fontSize: 14, fontFamily: "Satoshi"),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._recentSearches.map((q) => _recentSearchItem(q)).toList(),
      ],
    );
  }

  Widget _recentSearchItem(String q) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(Icons.history, size: 20, color: purple.withValues(alpha:0.3)),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () {
                _controller.text = q;
                _controller.selection = TextSelection.fromPosition(TextPosition(offset: q.length));
                _performSearch(q);
              },
              child: Text(
                q,
                style: TextStyle(color: purple, fontSize: 16, fontFamily: "Satoshi"),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _deleteSearch(q),
            child: Icon(Icons.close, size: 18, color: purple.withValues(alpha:0.3)),
          ),
        ],
      ),
    );
  }

  Widget _recipeCardSkeleton() {
    return SizedBox(
      width: 160.sw,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(
            width: 160.sw,
            height: 180.sh,
            borderRadius: BorderRadius.all(Radius.circular(20.sw)),
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

  String? _getSpellingSuggestion(String query) {
    if (query.isEmpty) return null;
    final q = query.toLowerCase().trim();
    const words = ["chocolate", "chicken", "beef", "pasta", "pizza", "cake", "cookie", "salad", "soup", "bread", "breakfast", "dinner", "lunch", "dessert", "snack"];

    String? bestMatch;
    int bestDist = 3; 

    for (var w in words) {
      int dist = _levenshtein(q, w);
      if (dist == 0) return null;
      if (dist < bestDist) {
        bestDist = dist;
        bestMatch = w;
      }
    }
    return bestMatch; 
  }
}

class _StaggeredItem extends StatelessWidget {
  final Widget child;
  final int index;
  const _StaggeredItem({required this.child, required this.index});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (index * 50).clamp(0, 400)),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
