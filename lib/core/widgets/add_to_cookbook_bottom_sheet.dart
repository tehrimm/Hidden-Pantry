import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_service.dart';
import 'create_cookbook_bottom_sheet.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';

class AddToCookbookBottomSheet extends StatefulWidget {
  final Recipe recipe;

  const AddToCookbookBottomSheet({
    super.key,
    required this.recipe,
  });

  @override
  State<AddToCookbookBottomSheet> createState() => _AddToCookbookBottomSheetState();
}

class _AddToCookbookBottomSheetState extends State<AddToCookbookBottomSheet> {
  final RecipeService _recipeService = RecipeService();
  
  Set<String> _initialCookbookIds = {};
  String? _selectedCookbookId;
  bool _loadingSelection = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentSelection();
  }

  Future<void> _loadCurrentSelection() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final ids = await _recipeService.getCookbookIdsForRecipe(user.uid, widget.recipe.id);
      if (mounted) {
        setState(() {
          _initialCookbookIds = Set.from(ids);
         
          if (ids.isNotEmpty) {
            _selectedCookbookId = ids.first;
          }
          _loadingSelection = false;
        });
      }
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
            await _recipeService.createCookbook(user.uid, title, desc);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      height: 400,
      margin: const EdgeInsets.all(20),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: const Color(0xFFF9E3D5),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Stack(
        children: [
          // Drag handle
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 96,
                height: 2,
                decoration: BoxDecoration(
                  color: const Color(0xFF74503C),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),

          const Positioned(
            top: 41,
            left: 0,
            right: 0,
            child: Text(
              'Add to cookbook',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF462F4D),
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'Satoshi',
              ),
            ),
          ),

          // List
          Positioned.fill(
            top: 90,
            bottom: 80,
            child: _loadingSelection 
              ? const Center(child: CircularProgressIndicator())
              : StreamBuilder<List<Map<String, dynamic>>>(
                stream: _recipeService.getUserCookbooks(user.uid),
                builder: (context, snapshot) {
                  final cookbooksData = snapshot.data ?? [];
                  List<Map<String, dynamic>> list = List.from(cookbooksData);
                  
                  bool hasFav = list.any((c) => (c['title']?.toString() ?? '').toLowerCase() == 'favorite');
                  if (!hasFav) {
                    list.insert(0, {
                      'id': 'favorite_internal',
                      'title': 'Favorite',
                      'recipeIds': [],
                      'imageUrl': 'https://firebasestorage.googleapis.com/v0/b/codeless-app.appspot.com/o/projects%2F0SFgeaWcBaf42xoFOlKx%2F30e754093184968999456bbb19bc604bae3ef8f7image%2037.png?alt=media&token=d46a734b-2eda-4f61-8278-aa825a23d4b4',
                    });
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 19),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = list[index];
                      final id = item['id'];
                      final isSelected = _selectedCookbookId == id;

                      return TweenAnimationBuilder<double>(
                        duration: Duration(milliseconds: 300 + (index * 50)),
                        tween: Tween(begin: 0.0, end: 1.0),
                        curve: Curves.easeOutBack,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: Opacity(
                              opacity: value.clamp(0.0, 1.0),
                              child: child,
                            ),
                          );
                        },
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              if (_selectedCookbookId == id) {
                                _selectedCookbookId = null; // Unselect
                              } else {
                                _selectedCookbookId = id;
                              }
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            height: 61,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF462F4D) : const Color(0xFFFFF2EA),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: isSelected ? [
                                BoxShadow(
                                  color: const Color(0xFF462F4D).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                )
                              ] : [],
                              border: Border.all(
                                color: isSelected ? Colors.transparent : const Color(0xFF74503C).withValues(alpha: 0.1),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  width: isSelected ? 48 : 44,
                                  height: isSelected ? 42 : 38,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey[300],
                                        image: item['imageUrl'] != null 
                                          ? DecorationImage(image: NetworkImage(item['imageUrl']), fit: BoxFit.cover)
                                          : null,
                                      ),
                                      child: item['imageUrl'] == null 
                                        ? const Icon(Icons.restaurant, size: 20)
                                        : null,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['title'],
                                        style: TextStyle(
                                          color: isSelected ? const Color(0xFFFFF2EA) : Colors.black,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Satoshi',
                                        ),
                                      ),
                                      Text(
                                        '${(item['recipeIds'] as List?)?.length ?? 0} recipes',
                                        style: TextStyle(
                                          color: isSelected ? const Color(0xFFFFF2EA).withValues(alpha: 0.7) : Colors.black54,
                                          fontSize: 10,
                                          fontFamily: 'Satoshi',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(Icons.check_circle, color: Color(0xFFEF8A54), size: 22),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
          ),

          // Plus button bottom left
          Positioned(
            left: 19,
            bottom: 13,
            child: GestureDetector(
              onTap: _showCreateCookbook,
              child: Container(
                width: 52,
                height: 53,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF2EA),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.add, color: Color(0xFF74503C), size: 24),
              ),
            ),
          ),

          // Save button
          Positioned(
            left: 79,
            right: 19,
            bottom: 13,
            child: GestureDetector(
              onTap: () async {
                try {
                  // 1. Handle Unsaving from old folders
                  for (var oldId in _initialCookbookIds) {
                    if (oldId != _selectedCookbookId && oldId != 'favorite_internal') {
                      await _recipeService.removeRecipeFromCookbook(user.uid, oldId, widget.recipe.id);
                    }
                  }

                  // 2. Handle Saving to new folder
                  if (_selectedCookbookId != null) {
                    String actualId = _selectedCookbookId!;
                    
                    // If it's the placeholder, get or create the real one
                    if (actualId == 'favorite_internal') {
                      actualId = await _recipeService.getOrCreateFavoriteCookbook(user.uid);
                    }
                    
                      await _recipeService.addRecipeToCookbook(
                        user.uid, 
                        actualId, 
                        widget.recipe.id, 
                        widget.recipe.imageUrl
                      );
                    }

                  if (mounted) {
                    Toaster.show(
                      context, 
                      _selectedCookbookId == null ? 'Recipe unsaved' : 'Recipe saved successfully!',
                      atTop: false,
                    );
                    Navigator.pop(context, _selectedCookbookId != null);
                  }
                } catch (e) {
                  if (mounted) {
                    Toaster.show(context, 'Error: $e', isError: true);
                  }
                }
              },
              child: Container(
                height: 53,
                decoration: BoxDecoration(
                  color: const Color(0xFFE48E5B),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Text(
                    'Save',
                    style: TextStyle(
                      color: Color(0xFFFFF2EA),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Satoshi',
                    ),
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
