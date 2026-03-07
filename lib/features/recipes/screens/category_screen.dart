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

class CategoriesScreen extends StatefulWidget {
  final String title;
  final String? tag;
  final String? query; // Added query parameter
  final List<String> allergies;
  final List<String>? authorIds; // Added authorIds for following feed

  const CategoriesScreen({
    super.key,
    required this.title,
    this.tag,
    this.query,
    this.allergies = const [],
    this.authorIds,
  });

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final RecipeApiService api = const RecipeApiService(baseUrl: ApiConstants.baseUrl);

  bool loading = true;
  List<Recipe> recipes = [];
  String? loadError;
  Map<String, num> _tagWeights = {};
  Set<String> _recentViewed = {};
  Set<String> _followedAuthorIds = {};
  final FollowService _followService = FollowService();

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    setState(() {
      loading = true;
      loadError = null;
    });

    try {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final snap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          final data = snap.data();
          if (data != null && data['tagWeights'] is Map) {
            final tw = data['tagWeights'] as Map;
            _tagWeights = tw.map((k, v) => MapEntry(k.toString().toLowerCase(), num.tryParse(v.toString()) ?? 0));
          }
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
            final f = await _followService.getFollowedAuthorIds();
            _followedAuthorIds = f.toSet();
          } catch (_) {}
        }
      } catch (_) {}

      if (widget.authorIds != null && widget.authorIds!.isNotEmpty) {
        final res = await api.fetchFollowingFeed(widget.authorIds!, limit: 50);
        if (!mounted) return;
        setState(() {
          recipes = _rerankByPreferences(res);
          loading = false;
        });
        return;
      }

      // Determine query: Use explicit query if provided, else default logic
      final String? query = widget.query ?? 
          (widget.tag == null || widget.tag == "All" ? "popular" : widget.tag);
      
      final String? tagParam = (widget.tag == "All") ? null : widget.tag;

      final res = await api.recommend(
        query: query,
        tag: tagParam,
        allergies: widget.allergies,
        topK: 20, // Fetch more for a list
        minRating: 3.5,
      );

      if (!mounted) return;
      setState(() {
        recipes = _rerankByPreferences(res);
        loading = false;
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
         borderRadius: BorderRadius.circular(30),
        child: Container(
          color: bg,
          child: Stack(
            children: [
              const _CategoryBackgroundPattern(),
              
              // Back Button
              Positioned(
                top: 51,
                left: 30,
                child: SafeArea(
                  top: false, // Positioned manually
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9E3D5),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/icons/backButton.png',
                          width: 18,
                          height: 18,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.arrow_back_ios_new,
                            size: 18,
                            color: Color(0xFF433020),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Title
               Positioned(
                  left: 103, // Aligned with snippet
                  top: 61,
                  child: SizedBox(
                    width: 250,
                    child: Text(
                      widget.title == widget.tag ? _beautify(widget.title) : widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF462F4D),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Satoshi',
                      ),
                    ),
                  ),
                ),

              // Content
              Positioned.fill(
                top: 130, // Below title area
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
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
        padding: const EdgeInsets.only(bottom: 20, top: 10),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 157 / 231,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => const SkeletonBox(
          width: double.infinity,
          height: double.infinity,
          borderRadius: BorderRadius.all(Radius.circular(20)),
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
      return const Center(
        child: Text(
          "No recipes found.",
          style: TextStyle(
            color: Color(0xFF462F4D),
            fontSize: 16,
            fontFamily: 'Satoshi',
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 20, top: 10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 157 / 231, // Match snippet ratio
        crossAxisSpacing: 15, // Approx space
        mainAxisSpacing: 15,
      ),
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final r = recipes[index];
        return _buildRecipeCard(r);
      },
    );
  }

  Widget _buildRecipeCard(Recipe r) {
    return RecipeCard(
      recipe: r,
      onTap: () => _openRecipe(r),
    );
  }
}

class _CategoryBackgroundPattern extends StatelessWidget {
  const _CategoryBackgroundPattern();

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

