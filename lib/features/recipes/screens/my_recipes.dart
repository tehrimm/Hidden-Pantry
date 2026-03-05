import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_service.dart';
import 'package:hidden_pantry_app/core/widgets/skeletons.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'recipe_details.dart';

class MyRecipesScreen extends StatefulWidget {
  const MyRecipesScreen({super.key});

  @override
  State<MyRecipesScreen> createState() => _MyRecipesScreenState();
}

class _MyRecipesScreenState extends State<MyRecipesScreen> {
  final Color bg = const Color(0xFFFFF3EB);
  final Color purple = const Color(0xFF462F4D);
  final Color cardColor = const Color(0xFFF9E3D5);
  final Color orange = const Color(0xFFEF8A54);

  final RecipeService _recipeService = RecipeService();
  
  String? _name;
  String? _bio;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Try regular users first
      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (!doc.exists) {
        // Try nutritionists
        doc = await FirebaseFirestore.instance
            .collection('nutritionists')
            .doc(user.uid)
            .get();
      }
      
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _name = data['fullName'] ?? user.displayName ?? "Hidden Pantry";
          _bio = data['bio'] ?? (doc.reference.parent.id == 'nutritionists' ? "Dedicated nutritionist." : "Passionate about cooking.");
          _photoUrl = data['photoUrl'] ?? user.photoURL;
        });
      } else if (mounted) {
        setState(() {
          _name = user.displayName ?? "Hidden Pantry";
          _photoUrl = user.photoURL;
        });
      }
    } catch (e) {
      if (mounted) {}
    }
  }

  Future<void> _confirmDelete(Recipe recipe) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bg,
        title: Text('Delete Recipe', style: TextStyle(color: purple, fontFamily: 'Satoshi', fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "${recipe.name}"?', style: TextStyle(color: purple, fontFamily: 'Satoshi')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: purple, fontFamily: 'Satoshi')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontFamily: 'Satoshi', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Show loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleting "${recipe.name}"...', style: const TextStyle(fontFamily: 'Satoshi'))),
        );
        
        await _recipeService.deleteRecipe(recipe.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recipe deleted successfully', style: TextStyle(fontFamily: 'Satoshi'))),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e', style: const TextStyle(fontFamily: 'Satoshi'))),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text("Please login")));

    return Scaffold(
      backgroundColor: Colors.white,
      body: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Container(
          color: bg,
            child: Stack(
              children: [
                const PatternBackground(),

                // Standardized Header - Back Button
                Positioned(
                  left: 30,
                  top: 51,
                  child: BackButtonWidget(color: purple),
                ),

                // Standardized Header - Title
                Positioned(
                  left: 0,
                  right: 0,
                  top: 51,
                  height: 50,
                  child: Center(
                    child: Text(
                      'My Recipes',
                      style: TextStyle(
                        color: purple,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Satoshi',
                      ),
                    ),
                  ),
                ),



                SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 50), // Gap for standardized header
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),
                            Center(child: _buildProfileSection()),
                            const SizedBox(height: 30),
                            Text(
                              "My Recipes",
                              style: TextStyle(
                                color: purple,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Satoshi',
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildRecipeList(user.uid),
                            const SizedBox(height: 30),
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
    );
  }


  Widget _buildProfileSection() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: Container(
            width: 80,
            height: 80,
            color: const Color(0xFFD9D9D9),
            child: _photoUrl != null
                ? Image.network(_photoUrl!, fit: BoxFit.cover)
                : Image.asset('assets/Logos/profile_placeholder.png', scale: 2),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _name ?? 'Hidden Pantry',
          style: TextStyle(
            color: purple,
            fontSize: 15,
            fontWeight: FontWeight.bold,
            fontFamily: 'Satoshi',
          ),
        ),
        const SizedBox(height: 5),
        Text(
          _bio ?? 'Passionate about cooking.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: purple,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
            fontFamily: 'Satoshi',
          ),
        ),
      ],
    );
  }

  Widget _buildRecipeList(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('recipes')
          .where('author_id', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Text(
                "You haven't uploaded any recipes yet.",
                style: TextStyle(color: purple.withValues(alpha:0.6), fontFamily: "Satoshi"),
              ),
            ),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 157 / 231,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final recipe = Recipe.fromJson(data);

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecipeDetailsScreen(recipe: recipe),
                  ),
                );
              },
              onLongPress: () => _confirmDelete(recipe),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                ),
                child: Stack(
                  children: [
                    // Image
                    Positioned.fill(
                      bottom: 50,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: (recipe.imageUrl != null && recipe.imageUrl!.trim().isNotEmpty)
                            ? Image.network(
                                recipe.imageUrl!,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, progress) => progress == null
                                    ? child
                                    : const SkeletonBox(
                                        width: double.infinity,
                                        height: double.infinity,
                                        borderRadius: BorderRadius.all(Radius.circular(20)),
                                      ),
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
                    ),
                    // Recipe Name
                    Positioned(
                      left: 12,
                      bottom: 28,
                      right: 12,
                      child: Text(
                        recipe.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: purple,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Satoshi',
                        ),
                      ),
                    ),
                    // Time and Rating
                    Positioned(
                      left: 12,
                      bottom: 10,
                      child: Text(
                        '${recipe.minutes} min  •  ⭐ ${recipe.avgRating.toStringAsFixed(1)}',
                        style: TextStyle(
                          color: purple.withValues(alpha:0.75),
                          fontSize: 11,
                          fontFamily: 'Satoshi',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}




