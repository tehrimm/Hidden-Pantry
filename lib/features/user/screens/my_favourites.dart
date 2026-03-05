import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_service.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_api_service.dart';
import 'package:hidden_pantry_app/core/constants/api_constants.dart';
import 'package:hidden_pantry_app/features/recipes/screens/recipe_details.dart';
import 'package:hidden_pantry_app/core/widgets/skeletons.dart';

class MyFavouritesScreen extends StatefulWidget {
  const MyFavouritesScreen({super.key});

  @override
  State<MyFavouritesScreen> createState() => _MyFavouritesScreenState();
}

class _MyFavouritesScreenState extends State<MyFavouritesScreen> {
  final RecipeService _recipeService = RecipeService();
  
  // Colors
  static const Color bg = Color(0xFFFFF3EB);
  static const Color purple = Color(0xFF462F4D);
  static const Color brown = Color(0xFF433020);
  
  bool _loading = true;
  List<Recipe> _recipes = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFavourites();
  }

  Future<void> _loadFavourites() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      // 1. Get List of ID strings
      final likedIds = await _recipeService.getLikedRecipeIds(user.uid);
      
      if (likedIds.isEmpty) {
        if (mounted) setState(() {
          _recipes = [];
          _loading = false;
        });
        return;
      }

      // 2. Fetch full recipe objects from Firestore
      final firestoreRecipes = await _recipeService.getRecipesByIds(likedIds);
      
      // 3. Any missing IDs might be from the FastAPI backend
      final firestoreIds = firestoreRecipes.map((r) => r.id).toSet();
      final missingIds = likedIds.where((id) => !firestoreIds.contains(id)).toList();
      
      final apiRecipes = <Recipe>[];
      if (missingIds.isNotEmpty) {
        final apiService = const RecipeApiService(baseUrl: ApiConstants.baseUrl);
        final futures = missingIds.map((id) async {
          try {
            return await apiService.getRecipeById(id);
          } catch (_) {
            return null; // Ignore errors for deleted/missing recipes
          }
        });
        
        final results = await Future.wait(futures);
        apiRecipes.addAll(results.whereType<Recipe>());
      }
      
      if (mounted) {
        setState(() {
          _recipes = [...firestoreRecipes, ...apiRecipes];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Could not load favourites.";
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          const PatternBackground(),

          SafeArea(
            child: Column(
              children: [
                // Fixed Header
                SizedBox(
                  height: 60,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 20,
                        top: 10,
                        child: BackButtonWidget(
                          onPressed: () => Navigator.pop(context),
                          color: brown,
                        ),
                      ),
                      Positioned.fill(
                        child: Center(
                          child: Text(
                            "My Favourites",
                            style: const TextStyle(
                              color: purple, // Consistent title color
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              fontFamily: "Satoshi",
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: _buildBody(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: purple)),
            TextButton(onPressed: _loadFavourites, child: const Text("Retry")),
          ],
        ),
      );
    }

    if (_recipes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_border, size: 60, color: purple.withValues(alpha:0.3)),
            const SizedBox(height: 16),
            Text(
              "No favourites yet.",
              style: TextStyle(
                color: purple.withValues(alpha:0.6),
                fontFamily: "Satoshi",
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Heart recipes to save them here!",
              style: TextStyle(
                color: purple.withValues(alpha:0.4),
                fontFamily: "Satoshi",
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 157 / 231,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
      ),
      itemCount: _recipes.length,
      itemBuilder: (context, index) {
        return _recipeCard(_recipes[index]);
      },
    );
  }

  Widget _recipeCard(Recipe r) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RecipeDetailsScreen(recipe: r)),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: (r.imageUrl != null && r.imageUrl!.isNotEmpty)
                        ? Image.network(
                            r.imageUrl!,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, event) {
                              if (event == null) return child;
                              return const SkeletonBox(width: double.infinity, height: double.infinity);
                            },
                            errorBuilder: (_, __, ___) => Image.asset(
                              'assets/Logos/recipe_placeholder.jpg',
                              fit: BoxFit.cover,
                            ),
                          )
                        : Image.asset(
                            'assets/Logos/recipe_placeholder.jpg',
                            fit: BoxFit.cover,
                          ),
                  ),
                  
                  // Gradient for text legibility if needed, or just keep clean
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            r.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: purple,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              fontFamily: 'Satoshi',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${r.minutes} min  •  ⭐ ${r.avgRating.toStringAsFixed(1)}',
            style: TextStyle(
              color: purple.withValues(alpha:0.75),
              fontSize: 11,
              fontFamily: 'Satoshi',
            ),
          ),
        ],
      ),
    );
  }
}
