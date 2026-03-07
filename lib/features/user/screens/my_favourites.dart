import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_service.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_api_service.dart';
import 'package:hidden_pantry_app/core/constants/api_constants.dart';
import 'package:hidden_pantry_app/features/recipes/screens/recipe_details.dart';
import 'package:hidden_pantry_app/features/recipes/widgets/recipe_card.dart';

class MyFavouritesScreen extends StatefulWidget {
  final bool isNutritionist;
  const MyFavouritesScreen({super.key, this.isNutritionist = false});

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
      final recipes = await _recipeService.getRecipesByIds(likedIds);
      
      if (mounted) {
        setState(() {
          _recipes = recipes;
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
    final double topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: widget.isNutritionist ? Colors.white : bg,
      body: ClipRRect(
        borderRadius: widget.isNutritionist ? BorderRadius.circular(30) : BorderRadius.zero,
        child: Container(
          color: bg,
          child: Stack(
            children: [
              const PatternBackground(),

              // Standardized Header - Back Button
              Positioned(
                left: 30,
                top: topPad + 20,
                child: BackButtonWidget(
                  color: brown,
                  onPressed: () => Navigator.pop(context),
                ),
              ),

              // Standardized Header - Title
              Positioned(
                left: 0,
                right: 0,
                top: topPad + 20,
                height: 50,
                child: const Center(
                  child: Text(
                    "My Favourites",
                    style: TextStyle(
                      color: purple,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: "Satoshi",
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: Column(
                  children: [
                    SizedBox(height: topPad + 70), // Responsive gap for header
                    Expanded(
                      child: _buildBody(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text(
            "My Favourites",
            style: TextStyle(
              color: purple,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Satoshi',
            ),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 157 / 231,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
            ),
            itemCount: _recipes.length,
            itemBuilder: (context, index) {
              final r = _recipes[index];
              return RecipeCard(
                recipe: r,
                isNutritionist: widget.isNutritionist,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => RecipeDetailsScreen(recipe: r)),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
