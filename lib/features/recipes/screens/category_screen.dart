import 'dart:developer';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_api_service.dart';
import 'package:hidden_pantry_app/core/widgets/skeletons.dart';
import 'package:hidden_pantry_app/features/recipes/screens/recipe_details.dart';
import 'package:hidden_pantry_app/core/constants/api_constants.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hidden_pantry_app/features/user/services/follow_service.dart';
import 'package:hidden_pantry_app/features/recipes/widgets/recipe_card.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';
import 'package:hidden_pantry_app/core/widgets/food_loader.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';


class CategoriesScreen extends StatefulWidget {
  final String title;
  final String? tag;
  final String? query; // Added query parameter
  final List<String> allergies;
  final List<String>? authorIds; // Added authorIds for following feed
  final RecipeApiService? apiService;

  const CategoriesScreen({
    super.key,
    required this.title,
    this.tag,
    this.query,
    this.allergies = const [],
    this.authorIds,
    this.apiService,
  });

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late final RecipeApiService api;

  bool loading = true;
  List<Recipe> recipes = [];
  String? loadError;
  Map<String, num> _tagWeights = {};
  Set<String> _recentViewed = {};
  Set<String> _followedAuthorIds = {};
  final FollowService _followService = FollowService();

  int _limit = 20;
  bool _loadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    api = widget.apiService ?? const RecipeApiService(baseUrl: ApiConstants.baseUrl);
    _loadRecipes();
  }

  Future<void> _loadRecipes({bool isLoadMore = false}) async {
    if (!isLoadMore) {
      setState(() {
        loading = true;
        loadError = null;
        _hasMore = true;
      });
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      final futures = <Future>[];
      List<Recipe> fetchedRecipes = [];

      if (user != null) {
        futures.add(FirebaseFirestore.instance.collection('users').doc(user.uid).get().then((snap) {
          final data = snap.data();
          if (data != null && data['tagWeights'] is Map) {
            final tw = data['tagWeights'] as Map;
            _tagWeights = tw.map((k, v) => MapEntry(k.toString().toLowerCase(), num.tryParse(v.toString()) ?? 0));
          }
        }).catchError((_) {}));

        futures.add(FirebaseFirestore.instance.collection('users').doc(user.uid).collection('views')
            .orderBy('lastViewed', descending: true).limit(200).get().then((recentSnap) {
          _recentViewed = recentSnap.docs.map((d) => d.id).toSet();
        }).catchError((_) {}));

        futures.add(_followService.getFollowedAuthorIds().then((f) {
          _followedAuthorIds = f.toSet();
        }).catchError((_) {}));
      }

      if (widget.authorIds != null && widget.authorIds!.isNotEmpty) {
        futures.add(api.fetchFollowingFeed(widget.authorIds!, limit: _limit).then((res) {
           fetchedRecipes = res;
        }).catchError((_) {}));
      } else {
        final String? query = widget.query ?? (widget.tag == null || widget.tag == "All" ? "popular" : widget.tag);
        final String? tagParam = (widget.tag == "All") ? null : widget.tag;
        
        futures.add(api.recommend(
          query: query,
          tag: tagParam,
          allergies: widget.allergies,
          topK: _limit,
          minRating: 3.5,
        ).then((res) {
           fetchedRecipes = res;
        }).catchError((_) {}));
      }

      await Future.wait(futures);
      final res = fetchedRecipes;

      if (!mounted) return;
      setState(() {
        final reRanked = _rerankByPreferences(res);
        if (isLoadMore) {
          final existingIds = recipes.map((r) => r.id).toSet();
          final actuallyNew = reRanked.where((r) => !existingIds.contains(r.id)).toList();
          recipes.addAll(actuallyNew);
          _loadingMore = false;
        } else {
          recipes = reRanked;
          loading = false;
        }

        if (res.length < _limit) _hasMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        loadError = e.toString();
      });
      log("Category load error: $e");
    }
  }

  void _openRecipe(Recipe r) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RecipeDetailsScreen(recipe: r)),
    );
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

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() {
      _loadingMore = true;
      _limit += 10;
    });
    await _loadRecipes(isLoadMore: true);
  }

  List<Recipe> _rerankByPreferences(List<Recipe> list) {
    if (list.isEmpty) return list;
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

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFFFF3EB);
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: ClipRRect(
         borderRadius: BorderRadius.circular(30.sw),
        child: Container(
          color: bg,
          child: Stack(
            children: [
              const PatternBackground(),
              
              // Back Button
              Positioned(
                top: 51.sh,
                left: 30.sw,
                child: SafeArea(
                  top: false, // Positioned manually
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 50.sw,
                      height: 50.sw,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9E3D5),
                        borderRadius: BorderRadius.circular(25.sw),
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/icons/back_button.png',
                          width: 18.sw,
                          height: 18.sw,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.arrow_back_ios_new,
                            size: 18.sw,
                            color: const Color(0xFF433020),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Title
               Positioned(
                  left: 103.sw, // Aligned with snippet
                  top: 61.sh,
                  child: SizedBox(
                    width: 250.sw,
                    child: Text(
                      widget.title == widget.tag ? _beautify(widget.title) : widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF462F4D),
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Satoshi',
                      ),
                    ),
                  ),
                ),

              // Content
              Positioned.fill(
                top: 130.sh, // Below title area
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 22.sw),
                  child: _buildBody(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (loading) {
       return GridView.builder(
        padding: EdgeInsets.only(bottom: 20.sh, top: 10.sh),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 157 / 250,
          crossAxisSpacing: 16.sw,
          mainAxisSpacing: 16.sh,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => SkeletonBox(
          width: double.infinity,
          height: double.infinity,
          borderRadius: BorderRadius.all(Radius.circular(20.sw)),
        ),
      );
    }

    if (loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Error: $loadError", textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF462F4D))),
            TextButton(onPressed: _loadRecipes, child: const Text("Retry")),
          ],
        ),
      );
    }

    if (recipes.isEmpty) {
      return Center(
        child: Text(
          "No recipes found.",
          style: TextStyle(
            color: const Color(0xFF462F4D),
            fontSize: 16.sp,
            fontFamily: 'Satoshi',
          ),
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.only(bottom: 20.sh, top: 10.sh),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 157 / 250, // Match snippet ratio
              crossAxisSpacing: 15.sw, // Approx space
              mainAxisSpacing: 15.sh,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final r = recipes[index];
                return _buildRecipeCard(r);
              },
              childCount: recipes.length,
            ),
          ),
        ),
        if (_hasMore)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20.sh),
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
                            fontSize: 14.sp,
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

  Widget _buildRecipeCard(Recipe r) {
    return RecipeCard(
      recipe: r,
      onTap: () => _openRecipe(r),
    );
  }
}

