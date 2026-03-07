import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:hidden_pantry_app/features/recipes/models/cookbook.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_service.dart';
import 'package:hidden_pantry_app/features/recipes/services/local_recipe_service.dart';
import 'package:hidden_pantry_app/core/widgets/create_cookbook_bottom_sheet.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:hidden_pantry_app/features/recipes/widgets/recipe_card.dart';
import 'package:hidden_pantry_app/core/widgets/home_bottom_nav.dart';
import 'package:hidden_pantry_app/features/recipes/screens/search/search.dart';
import 'package:hidden_pantry_app/features/recipes/upload/upload_recipe_step1.dart';
import 'package:hidden_pantry_app/features/nutritionist/screens/discovery.dart';
import 'package:hidden_pantry_app/core/widgets/main_navigation_shell.dart';
import 'package:hidden_pantry_app/core/services/view_mode_service.dart';
import 'recipe_details.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';

class SavedRecipesScreen extends StatefulWidget {
  final bool inShell;
  const SavedRecipesScreen({super.key, this.inShell = false});

  @override
  State<SavedRecipesScreen> createState() => _SavedRecipesScreenState();
}

class _SavedRecipesScreenState extends State<SavedRecipesScreen> {
  final Color bg = const Color(0xFFFFF3EB);
  final Color purple = const Color(0xFF462F4D);
  final Color cardColor = const Color(0xFFF9E3D5);
  final Color orange = const Color(0xFFEF8A54);

  final RecipeService _recipeService = RecipeService();
  final LocalRecipeService _localService = LocalRecipeService();
  
  String? _name;
  String? _bio;
  String? _photoUrl;
  bool _isOfflineView = false;

  String? _selectedCookbookId;
  String? _selectedCookbookDescription;
  List<String> _selectedRecipeIds = [];

  @override
  void initState() {
    super.initState();
    debugPrint('[SavedRecipesScreen] Initialized (inShell: ${widget.inShell})');
    _loadProfile();
    _checkNutritionistStatus();
    _initDefaultSelection();
  }

  Future<void> _refreshCurrentData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // If in offline view, the FutureBuilder will handle it on rebuild
    if (_isOfflineView) {
      if (mounted) setState(() {});
      return;
    }

    if (_selectedCookbookId == null) return;

    try {
      if (_selectedCookbookId == 'favorite_internal') {
        // Re-fetch the real fav cookbook ID first just in case
        final favId = await _recipeService.getOrCreateFavoriteCookbook(user.uid);
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('cookbooks')
            .doc(favId)
            .get();

        if (doc.exists && mounted) {
          final data = doc.data()!;
          setState(() {
            _selectedCookbookId = favId;
            _selectedRecipeIds = List<String>.from(data['recipeIds'] ?? []);
          });
        }
      } else {
        // Refresh specific cookbook
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('cookbooks')
            .doc(_selectedCookbookId!)
            .get();

        if (doc.exists && mounted) {
          final data = doc.data()!;
          setState(() {
            _selectedRecipeIds = List<String>.from(data['recipeIds'] ?? []);
            _selectedCookbookDescription = data['description'];
          });
        }
      }
    } catch (e) {
      print("Error refreshing cookbook: $e");
    }
  }

  Future<void> _initDefaultSelection() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final favId = await _recipeService.getOrCreateFavoriteCookbook(user.uid);
      
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cookbooks')
          .doc(favId)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _selectedCookbookId = favId;
          _selectedCookbookDescription = data['description'];
          _selectedRecipeIds = List<String>.from(data['recipeIds'] ?? []);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _selectedCookbookId = 'favorite_internal';
          _selectedRecipeIds = [];
        });
      }
    }
  }

  bool _isNutritionistInUserView = false;
  Future<void> _checkNutritionistStatus() async {
    final isNutr = await ViewModeService().isNutritionist();
    if (mounted) {
      setState(() => _isNutritionistInUserView = isNutr);
    }
  }

  void _onBottomTap(int i) {
    debugPrint('[SavedRecipesScreen] _onBottomTap: $i');
    if (widget.inShell) {
      debugPrint('[SavedRecipesScreen] inShell is true, ignoring internal tap logic');
      return;
    }
    if (i == 3) return; // Already here

    if (i == 0) {
      // If we got here, we are NOT in shell, so we should probably go TO the shell
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => MainNavigationShell()),
        (route) => false,
      );
    } else if (i == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SearchScreen()),
      );
    } else if (i == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const UploadRecipeStep1()),
      );
    } else if (i == 4) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const NutritionistDiscoveryScreen()),
      );
    }
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _name = data['fullName'] ?? user.displayName ?? "Hidden Pantry";
          _bio = data['bio'] ?? "Passionate about cooking.";
          _photoUrl = data['photoUrl'] ?? user.photoURL;
        });
      }
    } catch (e) {
      if (mounted) {}
    }
  }

  void _showCreateCookbook() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => CreateCookbookBottomSheet(
        onSave: (title, desc) async {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            try {
              await _recipeService.createCookbook(user.uid, title, desc);
              if (mounted) {
                Toaster.show(context, 'Cookbook created successfully!');
              }
            } catch (e) {
              if (mounted) {
                Toaster.show(context, 'Failed to create cookbook: $e', isError: true);
              }
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text("Please login")));
    final double topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: bg,
      body: Container(
        color: bg,
          child: Stack(
            children: [
              const PatternBackground(),

                // Removed Back Button to make it a top-level tab
                if (!widget.inShell)
                  Positioned(
                    left: 30,
                    top: topPad + 20,
                    child: const BackButtonWidget(),
                  ),

                // Standardized Header - Title
                Positioned(
                  left: 0,
                  right: 0,
                  top: topPad + 20,
                  height: 50,
                  child: Center(
                    child: Text(
                      'My Saved',
                      style: TextStyle(
                        color: purple,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Satoshi',
                      ),
                    ),
                  ),
                ),

                // Removed Settings Button as requested

                SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      SizedBox(height: topPad + 70), // Responsive gap for header
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),
                            Center(child: _buildProfileSection()),
                            const SizedBox(height: 30),
                            _buildToggle(),
                            const SizedBox(height: 30),
                            if (!_isOfflineView) ...[
                              _buildCookbookGrid(user.uid),
                              const SizedBox(height: 30),
                              if (_selectedCookbookId != null) ...[
                                if (_selectedCookbookDescription != null && _selectedCookbookDescription!.isNotEmpty) ...[
                                  Text(
                                    _selectedCookbookDescription!,
                                    style: TextStyle(
                                      color: purple.withValues(alpha: 0.7),
                                      fontSize: 14,
                                      fontStyle: FontStyle.italic,
                                      fontFamily: 'Satoshi',
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],
                                Text(
                                  "Saved Recipes",
                                  style: TextStyle(
                                    color: purple,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Satoshi',
                                  ),
                                ),
                                const SizedBox(height: 20),
                                _buildRecipeList(),
                              ],
                            ] else ...[
                              _buildOfflineSection(),
                            ],
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
      bottomNavigationBar: widget.inShell 
          ? null 
          : HpBottomNav(
              currentIndex: 3,
              onTap: _onBottomTap,
              orange: orange,
              isNutritionistInUserView: _isNutritionistInUserView,
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

  Widget _buildToggle() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha:0.5),
        borderRadius: BorderRadius.circular(25),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isOfflineView = false),
              child: Container(
                decoration: BoxDecoration(
                  color: !_isOfflineView ? orange : Colors.transparent,
                  borderRadius: BorderRadius.circular(21),
                ),
                alignment: Alignment.center,
                child: Text(
                  "Cookbooks",
                  style: TextStyle(
                    color: !_isOfflineView ? Colors.white : purple,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Satoshi',
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isOfflineView = true),
              child: Container(
                decoration: BoxDecoration(
                  color: _isOfflineView ? orange : Colors.transparent,
                  borderRadius: BorderRadius.circular(21),
                ),
                alignment: Alignment.center,
                child: Text(
                  "Downloads",
                  style: TextStyle(
                    color: _isOfflineView ? Colors.white : purple,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Satoshi',
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Offline Downloads",
          style: TextStyle(
            color: purple,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'Satoshi',
          ),
        ),
        const SizedBox(height: 20),
        FutureBuilder<List<Recipe>>(
          future: FirebaseAuth.instance.currentUser != null 
            ? _localService.getOfflineRecipes(FirebaseAuth.instance.currentUser!.uid)
            : Future.value([]),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final recipes = snapshot.data ?? [];
            if (recipes.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Text(
                    "No offline recipes found.",
                    style: TextStyle(color: purple.withValues(alpha:0.6), fontFamily: "Satoshi"),
                  ),
                ),
              );
            }
            return _buildRecipeGrid(recipes);
          },
        ),
      ],
    );
  }

  Widget _buildRecipeGrid(List<Recipe> recipes) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
      ),
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        return _recipeCard(recipe);
      },
    );
  }

  Widget _recipeCard(Recipe recipe) {
    return RecipeCard(
      recipe: recipe,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RecipeDetailsScreen(recipe: recipe),
          ),
        ).then((_) => _refreshCurrentData());
      },
    );
  }

  Widget _buildCookbookGrid(String userId) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _recipeService.getUserCookbooks(userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        
        final cookbooksData = snapshot.data ?? [];
        final List<Widget> cards = [];
        
        // 1. Always show 'Favorite' as the first card if not in DB
        final hasFavInDb = cookbooksData.any((c) => (c['title']?.toString() ?? '').toLowerCase() == 'favorite');
        
        if (!hasFavInDb) {
          cards.add(_buildCookbookCard(
            id: 'favorite_internal',
            title: 'Favorite',
            recipeIds: [],
            imageUrl: null,
            isDefault: true,
          ));
        }
        
        // 2. Add DB cookbooks
        for (var data in cookbooksData) {
          final cookbook = Cookbook.fromJson(data, data['id']);
          cards.add(_buildCookbookCard(
            id: cookbook.id,
            title: cookbook.title,
            description: cookbook.description,
            recipeIds: cookbook.recipeIds,
            imageUrl: cookbook.imageUrl,
          ));
        }
        
        // 3. Add "+" Button
        cards.add(_buildAddButton());

        return Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 20,
            runSpacing: 20,
            children: cards,
          ),
        );
      },
    );
  }

  Widget _buildCookbookCard({
    required String id,
    required String title,
    String? description,
    required List<String> recipeIds,
    String? imageUrl,
    bool isDefault = false,
  }) {
    final bool isSelected = _selectedCookbookId == id;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCookbookId = id;
          _selectedCookbookDescription = description;
          _selectedRecipeIds = recipeIds;
        });
      },
      child: Column(
        children: [
          Container(
            width: 75,
            height: 75,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(38),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9D9D9),
                      image: (imageUrl != null && imageUrl.trim().isNotEmpty)
                          ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
                          : isDefault 
                              ? const DecorationImage(
                                  image: NetworkImage('https://firebasestorage.googleapis.com/v0/b/codeless-app.appspot.com/o/projects%2F0SFgeaWcBaf42xoFOlKx%2F30e754093184968999456bbb19bc604bae3ef8f7image%2037.png?alt=media&token=d46a734b-2eda-4f61-8278-aa825a23d4b4'),
                                  fit: BoxFit.cover,
                                )
                              : null,
                    ),
                    child: (imageUrl == null && !isDefault) 
                      ? Icon(Icons.restaurant_menu, color: purple.withValues(alpha:0.5), size: 30)
                      : null,
                  ),
                ),
                if (isSelected)
                  Positioned.fill(
                    child: Container(
                      color: purple.withValues(alpha:0.4),
                      child: const Center(
                        child: Icon(Icons.check, color: Colors.white, size: 24),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: purple,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'Satoshi',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return Column(
      children: [
        GestureDetector(
          onTap: _showCreateCookbook,
          child: Container(
            width: 75,
            height: 75,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(38),
            ),
            child: const Icon(Icons.add, color: Color(0xFF74503C), size: 30),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Add',
          style: TextStyle(
            color: Colors.transparent,
            fontSize: 12,
            fontFamily: 'Satoshi',
          ),
        ),
      ],
    );
  }

  Widget _buildRecipeList() {
    if (_selectedRecipeIds.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Text(
            "No recipes in this cookbook.",
            style: TextStyle(color: purple.withValues(alpha:0.6), fontFamily: "Satoshi"),
          ),
        ),
      );
    }

    return FutureBuilder<List<Recipe>>(
      future: _recipeService.getRecipesByIds(_selectedRecipeIds),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final recipes = snapshot.data ?? [];
        if (recipes.isEmpty) {
          return Center(
            child: Text(
              "No recipes found.",
              style: TextStyle(color: purple.withValues(alpha:0.6), fontFamily: "Satoshi"),
            ),
          );
        }

        return _buildRecipeGrid(recipes);
      },
    );
  }
}




