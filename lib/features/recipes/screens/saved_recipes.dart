import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

    Widget content = Container(
      color: widget.inShell ? Colors.transparent : bg,
      child: Stack(
        children: [
          if (!widget.inShell) const PatternBackground(),
        
        // Force the Stack to be at least screen-sized to prevent RenderFlex overflow
        const SizedBox.expand(),
        
        // Header Illustration (Bleeding from top of screen)
        _headerIllustration(),

        Positioned.fill(
          child: SafeArea(
            bottom: !widget.inShell,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _headerText(),
                
                // Back button if not in shell
                if (!widget.inShell)
                   Padding(
                     padding: EdgeInsets.only(left: 25.sw, top: 10.sh),
                     child: const BackButtonWidget(),
                   ),

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
        ),
      ],
    ),
  );

    if (widget.inShell) return content;

    return Scaffold(
      backgroundColor: widget.inShell ? Colors.transparent : bg,
      body: content,
      bottomNavigationBar: HpBottomNav(
        currentIndex: 3,
        onTap: _onBottomTap,
        orange: orange,
        isNutritionistInUserView: _isNutritionistInUserView,
      ),
    );
  }




  Widget _buildToggle() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final sliderWidth = (totalWidth - 8.sw) / 2;
        
        return Container(
          height: 50.sh,
          decoration: BoxDecoration(
            color: cardColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(25.sw),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                left: _isOfflineView ? totalWidth / 2 : 4.sw,
                top: 4.sh,
                bottom: 4.sh,
                width: sliderWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: orange,
                    borderRadius: BorderRadius.circular(21.sw),
                    boxShadow: [
                      BoxShadow(
                        color: orange.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _isOfflineView = false);
                      },
                      child: Center(
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
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _isOfflineView = true);
                      },
                      child: Center(
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
            ],
          ),
        );
      }
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
        childAspectRatio: 157 / 250,
        crossAxisSpacing: 15.sw,
        mainAxisSpacing: 15.sh,
      ),
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 400 + (index * 100)),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeOutQuart,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: child,
              ),
            );
          },
          child: RecipeCard(
            recipe: recipes[index],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RecipeDetailsScreen(recipe: recipes[index]),
                ),
              );
            },
            onLongPress: () => _showRecipeOptions(recipes[index]),
          ),
        );
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
      onLongPress: () => _showRecipeOptions(recipe),
    );
  }

  Widget _buildCookbookGrid(List<Map<String, dynamic>> consolidatedCookbooks) {
    final List<Widget> cards = [];
    
    // Add DB/Consolidated cookbooks
    for (var data in consolidatedCookbooks) {
      final title = data['title']?.toString() ?? '';
      final isFavorite = data['isDefault'] == true || title.toLowerCase() == 'favorite';
      cards.add(_buildCookbookCard(
        id: data['id'],
        title: data['title'],
        description: data['description'],
        recipeIds: List<String>.from(data['recipeIds'] ?? []),
        imageUrl: data['imageUrl'],
        isDefault: isFavorite,
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
        HapticFeedback.selectionClick();
        setState(() {
          _selectedCookbookId = id;
        });
      },
      child: AnimatedScale(
        scale: isSelected ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 75.sw,
              height: 75.sw,
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(38.sw),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: purple.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  )
                ] : [],
                border: Border.all(
                  color: isSelected ? orange : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDefault ? Colors.redAccent.withValues(alpha: 0.1) : const Color(0xFFD9D9D9),
                        image: (!isDefault && imageUrl != null && imageUrl.trim().isNotEmpty)
                            ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
                            : null,
                      ),
                      child: isDefault
                        ? Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 30.sp)
                        : (imageUrl == null || imageUrl.trim().isEmpty) 
                          ? Icon(Icons.restaurant_menu, color: purple.withValues(alpha:0.5), size: 30.sp)
                          : null,
                    ),
                  ),
                  if (isSelected)
                    Positioned.fill(
                      child: Container(
                        color: purple.withValues(alpha:0.2),
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
                color: isSelected ? orange : purple,
                fontSize: 12.sp,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontFamily: 'Satoshi',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            _showCreateCookbook();
          },
          child: CustomPaint(
            painter: _DottedCirclePainter(color: orange),
            child: Container(
              width: 75.sw,
              height: 75.sw,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(38.sw),
              ),
              child: Icon(Icons.add_rounded, color: orange, size: 32.sp),
            ),
          ),
        ),
        SizedBox(height: 8.sh),
        Text(
          'Add new',
          style: TextStyle(
            color: orange,
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
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

  Widget _headerIllustration() {
    return Positioned(
      top: -45.sh,
      right: -35.sw,
      child: Container(
        width: 210.sw,
        height: 210.sw,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 25.clamp(0.0, 100.0).toDouble(),
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(105.sw),
          child: Image.asset(
            'assets/illustration/saves.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: Colors.white,
              child: Icon(Icons.bookmark_rounded, color: orange.withValues(alpha: 0.2), size: 60.sp),
            ),
          ),
        ),
      ),
    );
  }

  Widget _headerText() {
    return Container(
      width: double.infinity,
      height: 220.sh,
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Stack(
        children: [
          // Decorative Blobs
          Positioned(
            top: -40.sh,
            right: -20.sw,
            child: Container(
              width: 180.sw,
              height: 180.sw,
              decoration: BoxDecoration(
                color: orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Text Content
          Padding(
            padding: EdgeInsets.fromLTRB(25.sw, 40.sh, 140.sw, 20.sh),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.sw, vertical: 4.sh),
                  decoration: BoxDecoration(
                    color: orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10.sw),
                  ),
                  child: Text(
                    "MY LIBRARY",
                    style: TextStyle(
                      color: orange,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      fontFamily: "Satoshi",
                    ),
                  ),
                ),
                SizedBox(height: 12.sh),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: purple,
                      fontSize: 30.sp,
                      fontWeight: FontWeight.w900,
                      fontFamily: "Satoshi",
                      height: 1.1,
                    ),
                    children: [
                      const TextSpan(text: "Saved\n"),
                      TextSpan(
                        text: "Collection",
                        style: TextStyle(color: orange),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10.sh),
                Text(
                  "All your favorite recipes\nin one place.",
                  style: TextStyle(
                    color: purple.withValues(alpha: 0.6),
                    fontSize: 13.sp,
                    fontFamily: "Satoshi",
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRecipeOptions(Recipe recipe) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _modernActionSheet(
        title: "Recipe Options",
        subtitle: recipe.name,
        actions: [
          _actionItem(
            icon: Icons.share_rounded,
            label: "Share Recipe",
            color: orange,
            onTap: () {
              Navigator.pop(context);
              // Implementation for sharing
              Clipboard.setData(ClipboardData(text: "Check out this recipe: ${recipe.name}\n\nShared from Hidden Pantry"));
              Toaster.show(context, "Link copied to clipboard!");
            },
          ),
          _actionItem(
            icon: Icons.delete_outline_rounded,
            label: "Remove from Cookbook",
            color: Colors.red,
            onTap: () {
              Navigator.pop(context);
              _removeFromCookbook(recipe);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _removeFromCookbook(Recipe recipe) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _selectedCookbookId == null) return;

    try {
      if (_selectedCookbookId == 'favorite_internal') {
        await _recipeService.toggleFavorite(user.uid, recipe.id);
      } else {
        await _recipeService.removeRecipeFromCookbook(user.uid, _selectedCookbookId!, recipe.id);
      }
      if (mounted) {
        Toaster.show(context, "Removed from cookbook");
      }
    } catch (e) {
      if (mounted) {
        Toaster.show(context, "Error: $e", isError: true);
      }
    }
  }

  Widget _modernActionSheet({
    required String title,
    required String subtitle,
    required List<Widget> actions,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24.sw, vertical: 20.sh),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32.sw)),
        boxShadow: [
          BoxShadow(color: purple.withValues(alpha: 0.1), blurRadius: 40, offset: const Offset(0, -10)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40.sw, height: 4.sh,
            decoration: BoxDecoration(color: purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(2.sw)),
          ),
          SizedBox(height: 24.sh),
          Text(title, style: TextStyle(color: purple, fontSize: 20.sp, fontWeight: FontWeight.w900, fontFamily: "Satoshi")),
          SizedBox(height: 4.sh),
          Text(subtitle, style: TextStyle(color: purple.withValues(alpha: 0.4), fontSize: 13.sp, fontWeight: FontWeight.w500, fontFamily: "Satoshi")),
          SizedBox(height: 32.sh),
          ...actions.asMap().entries.map((entry) {
            final index = entry.key;
            final action = entry.value;
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 400 + (index * 100)),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: child,
                ),
              ),
              child: action,
            );
          }),
          SizedBox(height: 12.sh),
        ],
      ),
    );
  }

  Widget _actionItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.sh),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(20.sw),
          child: Container(
            padding: EdgeInsets.all(16.sw),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20.sw),
              border: Border.all(color: color.withValues(alpha: 0.1), width: 1),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.sw),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12.sw),
                  ),
                  child: Icon(icon, color: color, size: 20.sw),
                ),
                SizedBox(width: 16.sw),
                Text(
                  label,
                  style: TextStyle(
                    color: color == Colors.red ? Colors.red : purple,
                    fontWeight: FontWeight.w700,
                    fontSize: 16.sp,
                    fontFamily: "Satoshi",
                  ),
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_ios_rounded, color: color.withValues(alpha: 0.3), size: 14.sw),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DottedCirclePainter extends CustomPainter {
  final Color color;
  _DottedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2;
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const double dashWidth = 5;
    const double dashSpace = 3;
    double currentAngle = 0;

    final double circumference = 2 * 3.141592653589793 * radius;
    final int dashCount = (circumference / (dashWidth + dashSpace)).floor();

    for (int i = 0; i < dashCount; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(radius, radius), radius: radius),
        currentAngle,
        (dashWidth / circumference) * 2 * 3.141592653589793,
        false,
        paint,
      );
      currentAngle += ((dashWidth + dashSpace) / circumference) * 2 * 3.141592653589793;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

