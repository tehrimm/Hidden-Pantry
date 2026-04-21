import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';

class SavedRecipesScreen extends StatefulWidget {
  final bool inShell;
  const SavedRecipesScreen({super.key, this.inShell = false});

  @override
  State<SavedRecipesScreen> createState() => _SavedRecipesScreenState();
}

class _SavedRecipesScreenState extends State<SavedRecipesScreen> {
  final Color bg = const Color(0xFFFFF3EB);
  final Color purple = const Color(0xFF462F4D);
  final Color cardColor = const Color(0xFFFDECE4);
  final Color orange = const Color(0xFFEF8A54);

  final RecipeService _recipeService = RecipeService();
  final LocalRecipeService _localService = LocalRecipeService();
  
  String? _name;
  String? _bio;
  String? _photoUrl;
  bool _isOfflineView = false;

  String? _selectedCookbookId;

  @override
  void initState() {
    super.initState();
    debugPrint('[SavedRecipesScreen] Initialized (inShell: ${widget.inShell})');
    _loadProfile();
    _checkNutritionistStatus();
    _initDefaultSelection();
  }


  Future<void> _initDefaultSelection() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final favId = await _recipeService.getOrCreateFavoriteCookbook(user.uid);
      if (mounted) {
        setState(() {
          _selectedCookbookId = favId;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _selectedCookbookId = 'favorite_internal';
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
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SearchScreen()),
      );
    } else if (i == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const UploadRecipeStep1()),
      );
    } else if (i == 4) {
      Navigator.push(
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
    ResponsiveUtils.init(context);
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
            if (!widget.inShell)
              Positioned(
                left: 30.sw,
                top: topPad + 36.sh,
                child: const BackButtonWidget(),
              ),
            Positioned(
              left: 0,
              right: 0,
              top: topPad + 36.sh,
              height: 50.sh,
              child: Center(
                child: Text(
                  'My Saved',
                  style: TextStyle(
                    color: purple,
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Satoshi',
                  ),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  SizedBox(height: 96.sh),
                  Expanded(
                    child: StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _recipeService.getUserCookbooks(user.uid),
                      builder: (context, snapshot) {
                        final cookbooksData = snapshot.data ?? [];
                        List<Map<String, dynamic>> consolidatedCookbooks = List.from(cookbooksData);
                        final bool hasFavInDb = consolidatedCookbooks.any((c) => (c['title']?.toString() ?? '').toLowerCase() == 'favorite');
                        if (!hasFavInDb) {
                          consolidatedCookbooks.insert(0, {
                            'id': 'favorite_internal',
                            'title': 'Favorite',
                            'recipeIds': [],
                            'imageUrl': null,
                            'isDefault': true,
                          });
                        }

                        List<String> currentRecipeIds = [];
                        String? currentDesc;
                        if (!_isOfflineView) {
                          Map<String, dynamic>? selected;
                          if (_selectedCookbookId != null) {
                            selected = consolidatedCookbooks.cast<Map<String, dynamic>?>().firstWhere(
                              (c) => c?['id'] == _selectedCookbookId,
                              orElse: () => null,
                            );
                          }
                          if (selected == null && consolidatedCookbooks.isNotEmpty) {
                            selected = consolidatedCookbooks.first;
                          }
                          if (selected != null) {
                            currentRecipeIds = List<String>.from(selected['recipeIds'] ?? []);
                            currentDesc = selected['description'];
                          }
                        }

                        return SingleChildScrollView(
                          padding: EdgeInsets.symmetric(horizontal: 30.sw),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 20.sh),
                              Center(child: _buildProfileSection()),
                              SizedBox(height: 30.sh),
                              _buildToggle(),
                              SizedBox(height: 30.sh),
                              if (!_isOfflineView) ...[
                                _buildCookbookGrid(consolidatedCookbooks),
                                SizedBox(height: 30.sh),
                                if (currentRecipeIds.isNotEmpty || (_selectedCookbookId != null)) ...[
                                  if (currentDesc != null && currentDesc.isNotEmpty) ...[
                                    Text(
                                      currentDesc,
                                      style: TextStyle(
                                        color: purple.withValues(alpha: 0.7),
                                        fontSize: 14.sp,
                                        fontStyle: FontStyle.italic,
                                        fontFamily: 'Satoshi',
                                      ),
                                    ),
                                    SizedBox(height: 20.sh),
                                  ],
                                  Text(
                                    "Saved Recipes",
                                    style: TextStyle(
                                      color: purple,
                                      fontSize: 20.sp,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Satoshi',
                                    ),
                                  ),
                                  SizedBox(height: 20.sh),
                                  _buildRecipeList(currentRecipeIds),
                                ],
                              ] else ...[
                                _buildOfflineSection(),
                              ],
                              SizedBox(height: 30.sh),
                            ],
                          ),
                        );
                      },
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
          borderRadius: BorderRadius.circular(50.sw),
          child: Container(
            width: 80.sw,
            height: 80.sw,
            color: const Color(0xFFD9D9D9),
            child: _photoUrl != null
                ? Image.network(_photoUrl!, fit: BoxFit.cover)
                : Image.asset('assets/logos/profile_placeholder.png', scale: 2),
          ),
        ),
        SizedBox(height: 10.sh),
        Text(
          _name ?? 'Hidden Pantry',
          style: TextStyle(
            color: purple,
            fontSize: 15.sp,
            fontWeight: FontWeight.bold,
            fontFamily: 'Satoshi',
          ),
        ),
        SizedBox(height: 5.sh),
        Text(
          _bio ?? 'Passionate about cooking.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: purple,
            fontSize: 12.sp,
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
      height: 50.sh,
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha:0.5),
        borderRadius: BorderRadius.circular(25.sw),
      ),
      padding: EdgeInsets.all(4.sw),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isOfflineView = false),
              child: Container(
                decoration: BoxDecoration(
                  color: !_isOfflineView ? orange : Colors.transparent,
                  borderRadius: BorderRadius.circular(21.sw),
                ),
                alignment: Alignment.center,
                child: Text(
                  "Cookbooks",
                  style: TextStyle(
                    color: !_isOfflineView ? Colors.white : purple,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Satoshi',
                    fontSize: 14.sp,
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
                  borderRadius: BorderRadius.circular(21.sw),
                ),
                alignment: Alignment.center,
                child: Text(
                  "Downloads",
                  style: TextStyle(
                    color: _isOfflineView ? Colors.white : purple,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Satoshi',
                    fontSize: 14.sp,
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
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            fontFamily: 'Satoshi',
          ),
        ),
        SizedBox(height: 20.sh),
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
                  padding: EdgeInsets.only(top: 40.sh),
                  child: Text(
                    "No offline recipes found.",
                    style: TextStyle(color: purple.withValues(alpha:0.6), fontFamily: "Satoshi", fontSize: 14.sp),
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
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 15.sw,
        mainAxisSpacing: 15.sh,
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
        );
      },
    );
  }

  Widget _buildCookbookGrid(List<Map<String, dynamic>> consolidatedCookbooks) {
    final List<Widget> cards = [];
    
    // Add DB/Consolidated cookbooks
    for (var data in consolidatedCookbooks) {
      cards.add(_buildCookbookCard(
        id: data['id'],
        title: data['title'],
        description: data['description'],
        recipeIds: List<String>.from(data['recipeIds'] ?? []),
        imageUrl: data['imageUrl'],
      ));
    }
    
    // 3. Add "+" Button
    cards.add(_buildAddButton());

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 20.sw,
        runSpacing: 20.sh,
        children: cards,
      ),
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
        });
      },
      child: Column(
        children: [
          Container(
            width: 75.sw,
            height: 75.sw,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(38.sw),
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
                      ? Icon(Icons.restaurant_menu, color: purple.withValues(alpha:0.5), size: 30.sp)
                      : null,
                  ),
                ),
                if (isSelected)
                  Positioned.fill(
                    child: Container(
                      color: purple.withValues(alpha:0.4),
                      child: Center(
                        child: Icon(Icons.check, color: Colors.white, size: 24.sp),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 8.sh),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: purple,
              fontSize: 12.sp,
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
            width: 75.sw,
            height: 75.sw,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(38.sw),
            ),
            child: Icon(Icons.add, color: purple, size: 30.sp),
          ),
        ),
        SizedBox(height: 8.sh),
        Text(
          'Add',
          style: TextStyle(
            color: Colors.transparent,
            fontSize: 12.sp,
            fontFamily: 'Satoshi',
          ),
        ),
      ],
    );
  }

  Widget _buildRecipeList(List<String> recipeIds) {
    if (recipeIds.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.only(top: 20.sh),
          child: Text(
            "No recipes in this cookbook.",
            style: TextStyle(color: purple.withValues(alpha: 0.6), fontFamily: "Satoshi", fontSize: 14.sp),
          ),
        ),
      );
    }

    return FutureBuilder<List<Recipe>>(
      future: _recipeService.getRecipesByIds(recipeIds),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final recipes = snapshot.data ?? [];
        if (recipes.isEmpty) {
          return Center(
            child: Text(
              "No recipes found.",
              style: TextStyle(color: purple.withValues(alpha: 0.6), fontFamily: "Satoshi", fontSize: 14.sp),
            ),
          );
        }

        return _buildRecipeGrid(recipes);
      },
    );
  }
}

