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

class SearchScreen extends StatefulWidget {
  final bool inShell;
  final RecipeApiService? apiService;
  const SearchScreen({super.key, this.inShell = false, this.apiService});

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

  bool get _isUnderTest => widget.apiService != null;

  String? _suggestedQuery;
  int? _filterMaxMinutes;
  List<String> _filterTags = [];
  
  final FocusNode _searchFocus = FocusNode();

  final Color bg = const Color(0xFFFFF3EB);
  final Color searchBarBg = const Color(0xFFFDECE4);
  final Color purple = const Color(0xFF462F4D);
  final Color brown = const Color(0xFF433020);
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

  // Focus change handler removed (unused)

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
    
    // Remove if already exists to move to top
    history.remove(q);
    history.insert(0, q);
    
    // Limit to 10
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
      _performSearch(q);
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
    int bestDist = 3; // Max tolerance
    final lowerQ = query.toLowerCase();
    
    if (lowerQ.length < 3) return null;
    
    for (var kw in knownKeywords) {
      int d = _levenshtein(lowerQ, kw);
      if (d < bestDist && d > 0) { // Don't suggest if exact match
        bestDist = d;
        bestMatch = kw;
      }
    }
    return bestMatch;
  }

  Future<void> _performSearch(String query) async {
    print('DEBUG _performSearch: query="$query", ingredients=${_currentIngredients.length}, filters=${_filterTags.length}');
    setState(() {
      _hasSearched = true;
      _isSearching = true;
    });
    try {
      List<Recipe> firestoreResults = const [];
      if (!_isUnderTest) {
        firestoreResults = await RecipeService().searchRecipes(
          query,
          limit: 20,
          ingredients: _currentIngredients,
          maxMinutes: _filterMaxMinutes,
          tags: _filterTags,
        );
      }

      final apiResults = await _api.searchRecipes(
        query, 
        limit: 50, 
        ingredients: _currentIngredients,
        maxMinutes: _filterMaxMinutes,
        tags: _filterTags,
        allergies: _userAllergies.isNotEmpty ? _userAllergies : null,
      );

      if (mounted) {
        setState(() {
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
          _results = combined;
          _isSearching = false;
        });
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      print('DEBUG _performSearch ERROR: $e');
      if (mounted) {
        setState(() {
          _results = [];
          _isSearching = false;
        });
      }
    }
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
    
    // Dismiss keyboard
    FocusScope.of(context).unfocus();
    
    // Perform search in place
    await _performSearch(q);
    // Add to history is already done by _saveSearch
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
      print('DEBUG: Selected ingredients: $_currentIngredients');
      // Trigger search automatically with new ingredients
      if (_currentIngredients.isNotEmpty) {
        print('DEBUG: Triggering search with query: "${_controller.text}" and ${_currentIngredients.length} ingredients');
        _performSearch(_controller.text);
      } else {
        // Clear results if no ingredients selected
        print('DEBUG: No ingredients, clearing results');
        setState(() {
          _results = [];
        });
      }
    }
  }



  Future<void> _openCamera() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const IngredientCameraScreen()),
    );

    if (result != null && result is List<String>) {
      // Add new unique ingredients
      bool changed = false;
      for (var ingredient in result) {
        if (!_currentIngredients.contains(ingredient)) {
          _currentIngredients.add(ingredient);
          changed = true;
        }
      }
      
      if (changed) {
        setState(() {}); // Update UI
        // Proceed to Pantry as requested
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
          // Check if we should trigger search
          // If query is empty but filters are set, we might want to show filtered recommendations?
          // The searchRecipes API update we made handles empty query if filters exist.
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
      backgroundColor: bg,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          PatternBackground(),
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
                  if (_controller.text.isNotEmpty || _currentIngredients.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _ingredientsFilterRow(),
                  ],
                  Expanded(
                    child: (_controller.text.isEmpty && _currentIngredients.isEmpty && _results.isEmpty && !_hasSearched)
                        ? _recentSearchesSection()
                        : _resultsList(),
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
                debugPrint('[SearchScreen] _onBottomTap: $index');
                if (index == 1) return;
                if (index == 0) {
                  // If we got here, we are NOT in shell, so we should probably go TO the shell
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFFDECE4), // Match searchBarBg
                borderRadius: BorderRadius.circular(27),
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
                    child: Icon(Icons.arrow_back, size: 24, color: purple),
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
          // Show Pantry icon in initial state, Filter icon when searching/results are showing
          if (_results.isEmpty && _controller.text.isEmpty && _currentIngredients.isEmpty && _filterTags.isEmpty && _filterMaxMinutes == null)
            GestureDetector(
              onTap: _openPantry,
              child: Image.asset(
                'assets/food/pantry.png', 
                width: 28,
                height: 28,
                errorBuilder: (_, __, ___) => Icon(Icons.shopping_bag, size: 30, color: brown),
              ),
            )
          else
            GestureDetector(
              onTap: _openFilters,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9E3D5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.tune_rounded, size: 24, color: purple),
              ),
            ),
    
        ],
      ),
    );
  }

  Widget _ingredientsFilterRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
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
    );
  }



  Widget _resultsList() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFEF8A54)),
      );
    }

    if (_results.isEmpty && (_controller.text.isNotEmpty || _hasSearched)) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "No recipes found",
              textAlign: TextAlign.center,
              style: TextStyle(color: purple.withValues(alpha:0.6), fontFamily: "Satoshi"),
            ),
            const SizedBox(height: 8),
            Text(
              "Try removing some filters.",
              textAlign: TextAlign.center,
              style: TextStyle(color: purple.withValues(alpha:0.5), fontFamily: "Satoshi"),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(22),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 157 / 231, // Adjusted to match Home card proportions
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _results.length,
      itemBuilder: (_, i) {
        final r = _results[i];
        return RecipeCard(
          recipe: r,
          onTap: () {
            _saveSearch(r.name);
            _openRecipe(r);
          },
        );
      },
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

  
}
