import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';

class PantryScreen extends StatefulWidget {
  final List<String> initialSelectedIngredients;
  final bool showSelectedSection;
  
  const PantryScreen({
    super.key,
    this.initialSelectedIngredients = const [],
    this.showSelectedSection = false,
  });

  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen> {
  static const Color bg = Color(0xFFFFF3EB);
  static const Color primary = Color(0xFF462F4D);
  static const Color chipBg = Color(0xFFF5DDCE);
  static const Color chipText = Color(0xFF433020);
  static const Color cta = Color(0xFFF2894F);
  static const String csvAssetPath = 'assets/data/ingredients_categorized.csv';

  // categoryKey -> list of ingredients
  final Map<String, List<String>> _byCategory = {};
  final Set<String> _selected = {};
  final Map<String, bool> _expanded = {}; // Track expanded state per category

  bool _loading = true;
  String? _error;
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<_CategoryMeta> _categories = const [
    _CategoryMeta(keyName: 'Alcoholic Beverages', title: 'Alcoholic Beverages', iconAsset: 'assets/food/alcholic_beverages.png'),
    _CategoryMeta(keyName: 'Baby Food', title: 'Baby Food', iconAsset: 'assets/food/baby_food.png'),
    _CategoryMeta(keyName: 'Bakery & Breads', title: 'Bakery & Breads', iconAsset: 'assets/food/bakery_breads.png'),
    _CategoryMeta(keyName: 'Baking Ingredients', title: 'Baking Ingredients', iconAsset: 'assets/food/baking_ingredients.png'),
    _CategoryMeta(keyName: 'Baking Mixes', title: 'Baking Mixes', iconAsset: 'assets/food/baking.png'),
    _CategoryMeta(keyName: 'Beverages', title: 'Beverages', iconAsset: 'assets/food/beverages.png'),
    _CategoryMeta(keyName: 'Flours & Grains', title: 'Flours & Grains', iconAsset: 'assets/food/grains_and_cereals.png'),
    _CategoryMeta(keyName: 'Legumes & Pulses', title: 'Legumes & Pulses', iconAsset: 'assets/food/legumes_and_pulses.png'),
    _CategoryMeta(keyName: 'Cheese', title: 'Cheese', iconAsset: 'assets/food/cheese.png'),
    _CategoryMeta(keyName: 'Dairy & Alternatives', title: 'Dairy & Alternatives', iconAsset: 'assets/food/dairy.png'),
    _CategoryMeta(keyName: 'Candied Fruit', title: 'Candied Fruit', iconAsset: 'assets/food/candied_fruit.png'),
    _CategoryMeta(keyName: 'Fruits', title: 'Fruits', iconAsset: 'assets/food/fruits.png'),
    _CategoryMeta(keyName: 'Mushrooms & Fungi', title: 'Mushrooms & Fungi', iconAsset: 'assets/food/mushroom.png'),
    _CategoryMeta(keyName: 'Nuts & Seeds', title: 'Nuts & Seeds', iconAsset: 'assets/food/nuts_and_seeds.png'),
    _CategoryMeta(keyName: 'Oils & Vinegars', title: 'Oils & Vinegars', iconAsset: 'assets/food/oil.png'),
    _CategoryMeta(keyName: 'Fruits - Canned & Processed', title: 'Fruits - Canned & Processed', iconAsset: 'assets/food/packed_food.png'),
    _CategoryMeta(keyName: 'Pasta & Noodles', title: 'Pasta & Noodles', iconAsset: 'assets/food/pasta.png'),
    _CategoryMeta(keyName: 'Refrigerated Dough', title: 'Refrigerated Dough', iconAsset: 'assets/food/premade_dough.png'),
    _CategoryMeta(keyName: 'Seafood', title: 'Seafood', iconAsset: 'assets/food/seafood.png'),
    _CategoryMeta(keyName: 'Spices, Salts & Seasonings', title: 'Spices, Salts & Seasonings', iconAsset: 'assets/food/seasoning.png'),
    _CategoryMeta(keyName: 'Desserts & Sweets', title: 'Desserts & Sweets', iconAsset: 'assets/food/candy.png'),
    _CategoryMeta(keyName: 'Vegetables', title: 'Vegetables', iconAsset: 'assets/food/vegetables.png'),
    _CategoryMeta(keyName: 'Canned Goods', title: 'Canned Goods', iconAsset: 'assets/food/canned_goods.png'),
    _CategoryMeta(keyName: 'Cereals & Breakfast', title: 'Cereals & Breakfast', iconAsset: 'assets/food/cereal.png'),
    _CategoryMeta(keyName: 'Chocolate & Cocoa', title: 'Chocolate & Cocoa', iconAsset: 'assets/food/chocolate.png'),
    _CategoryMeta(keyName: 'Sauces & Condiments', title: 'Sauces & Condiments', iconAsset: 'assets/food/sauces.png'),
    _CategoryMeta(keyName: 'Dried Fruit', title: 'Dried Fruit', iconAsset: 'assets/food/dried_fruit.png'),
    _CategoryMeta(keyName: 'Eggs', title: 'Eggs', iconAsset: 'assets/food/eggs.png'),
    _CategoryMeta(keyName: 'Fats & Oils', title: 'Fats & Oils', iconAsset: 'assets/food/fats.png'),
    _CategoryMeta(keyName: 'Fermented Products', title: 'Fermented Products', iconAsset: 'assets/food/fermented.png'),
    _CategoryMeta(keyName: 'Frozen Foods', title: 'Frozen Foods', iconAsset: 'assets/food/frozen_foods.png'),
    _CategoryMeta(keyName: 'Herbs & Fresh Greens', title: 'Herbs & Fresh Greens', iconAsset: 'assets/food/herbs.png'),
    _CategoryMeta(keyName: 'Herbs & Supplements', title: 'Herbs & Supplements', iconAsset: 'assets/food/herbs_supplements.png'),
    _CategoryMeta(keyName: 'Jams & Preserves', title: 'Jams & Preserves', iconAsset: 'assets/food/jams.png'),
    _CategoryMeta(keyName: 'Meat & Poultry', title: 'Meat & Poultry', iconAsset: 'assets/food/meat.png'),
    _CategoryMeta(keyName: 'Nut Butters & Spreads', title: 'Nut Butters & Spreads', iconAsset: 'assets/food/nut_butter.png'),
    _CategoryMeta(keyName: 'Preserved Vegetables', title: 'Preserved Vegetables', iconAsset: 'assets/food/preserved_vegetables.png'),
    _CategoryMeta(keyName: 'Tofu & Meat Alternatives', title: 'Tofu & Meat Alternatives', iconAsset: 'assets/food/tofu_meat_alternatives.png'),
    _CategoryMeta(keyName: 'Sweeteners', title: 'Sweeteners', iconAsset: 'assets/food/sugar.png'),
    _CategoryMeta(keyName: 'Rice', title: 'Rice', iconAsset: 'assets/food/rice.png'),
    _CategoryMeta(keyName: 'Seaweed', title: 'Seaweed', iconAsset: 'assets/food/seaweed.png'),
    _CategoryMeta(keyName: 'Soups & Stocks', title: 'Soups & Stocks', iconAsset: 'assets/food/soups_stocks.png'),
    _CategoryMeta(keyName: 'Snacks & Other Ingredients', title: 'Snacks & Other Ingredients', iconAsset: 'assets/food/snacks.png'),
  ];

  bool _csvLoadAttempted = false;

  @override
  void initState() {
    super.initState();
    // Clear search when screen is first shown
    _searchController.clear();
    _searchQuery = '';
    
    // Initialize with provided ingredients
    _selected.addAll(widget.initialSelectedIngredients);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_csvLoadAttempted) {
      _csvLoadAttempted = true;
      _loadCsv(DefaultAssetBundle.of(context));
    }
  }

  Future<void> _loadCsv(AssetBundle bundle) async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final raw = await bundle.loadString(csvAssetPath);

      // Expected header: ingredient,category
      final lines = raw.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
      if (lines.isEmpty) throw Exception('CSV is empty.');

      final header = lines.first.toLowerCase().trim();
      if (!header.contains('ingredient') || !header.contains('category')) {
        throw Exception('CSV header must be: ingredient,category');
      }

      final map = <String, List<String>>{};
      for (int idx = 1; idx < lines.length; idx++) {
        final line = lines[idx].trim();
        if (line.isEmpty) continue;

        // Simple CSV split (your ingredient names don't include commas)
        final parts = line.split(',');
        if (parts.length < 2) continue;

        final ingredient = parts.first.trim();
        final category = parts.sublist(1).join(',').trim(); // safe if category contains commas (unlikely)

        if (ingredient.isEmpty || category.isEmpty) continue;

        map.putIfAbsent(category, () => <String>[]);
        map[category]!.add(ingredient);
      }

      // Keep UI ordering consistent + avoid null categories
      for (final c in _categories) {
        map.putIfAbsent(c.keyName, () => <String>[]);
        map[c.keyName]!.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      }

      setState(() {
        _byCategory
          ..clear()
          ..addAll(map);
          
        // Reconcile _selected casing with loaded CSV data
        // e.g. if _selected has "tomato" but CSV has "Tomato", switch to "Tomato"
        final newSelected = <String>{};
        final allLoadedLower = <String, String>{}; // lower -> original
        
        for (var list in map.values) {
          for (var item in list) {
            allLoadedLower[item.toLowerCase()] = item;
          }
        }
        
        for (final sel in _selected) {
           final lower = sel.toLowerCase();
           if (allLoadedLower.containsKey(lower)) {
             newSelected.add(allLoadedLower[lower]!);
           } else {
             newSelected.add(sel); // Keep original if not found
           }
        }
        _selected.clear();
        _selected.addAll(newSelected);
        
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _toggleIngredient(String name) {
    setState(() {
      if (_selected.contains(name)) {
        _selected.remove(name);
      } else {
        _selected.add(name);
      }
    });
  }

  

  void _toggleCategoryExpansion(String categoryKey) {
    setState(() {
      _expanded[categoryKey] = !(_expanded[categoryKey] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false, // Prevent keyboard from pushing content
      backgroundColor: bg,
      body: Container(
        color: bg,
        child: Stack(
          children: [
            // Background patterns (matching other screens)
            Positioned(
              left: (-154).sw,
              top: (-14).sh,
              child: Transform.rotate(
                angle: 21 * pi / 180,
                child: Container(
                  width: 271.sw,
                  height: 159.sh,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFF5DDCE)),
                    borderRadius: BorderRadius.all(Radius.elliptical(136.sw, 80.sh)),
                  ),
                ),
              ),
            ),
            Positioned(
              left: (-149).sw,
              top: (-100).sh,
              child: Transform.rotate(
                angle: 4 * pi / 180,
                child: Container(
                  width: 303.sw,
                  height: 329.sh,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFF5DDCE)),
                    borderRadius: BorderRadius.all(Radius.elliptical(152.sw, 165.sh)),
                  ),
                ),
              ),
            ),

            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.width >= 600 ? 24.sh : 35.sh),
                  _topBar(context),
                  SizedBox(height: 14.sh),
                  
                  // Title
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.sw),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "What's in your Fridge?",
                        style: TextStyle(
                          color: primary,
                          fontSize: 40.sp,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                          fontFamily: 'Satoshi',
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16.sh),

                  // Search Bar
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.sw),
                    child: Container(
                      height: max(52.0, 50.sh),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDECE4),
                        borderRadius: BorderRadius.circular(26.0),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value.toLowerCase();
                          });
                        },
                        style: TextStyle(
                          color: primary,
                          fontSize: 14.sp,
                          fontFamily: 'Satoshi',
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search ingredients...',
                          hintStyle: TextStyle(
                            color: const Color(0xFFA18671),
                            fontSize: 14.sp,
                            fontFamily: 'Satoshi',
                          ),
                          prefixIcon: Icon(Icons.search, color: const Color(0xFFA18671), size: 20.sw),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.close, size: 18.sw, color: primary),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16.sw, vertical: 14.sh),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16.sh),
                  
                  // Horizontal Selected Items
                  if (widget.showSelectedSection)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: _selected.isNotEmpty ? 40.sh : 0,
                      margin: EdgeInsets.only(bottom: _selected.isNotEmpty ? 12.sh : 0),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(horizontal: 20.sw),
                        itemCount: _selected.length,
                        separatorBuilder: (_, __) => SizedBox(width: 8.sw),
                        itemBuilder: (context, index) {
                          final item = _selected.elementAt(index);
                          return InkWell(
                            onTap: () => _toggleIngredient(item),
                            borderRadius: BorderRadius.circular(20.sw),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 14.sw),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: primary,
                                borderRadius: BorderRadius.circular(20.sw),
                                boxShadow: [
                                  BoxShadow(color: primary.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2))
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    item,
                                    style: TextStyle(
                                      color: const Color(0xFFFFF2EA),
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Satoshi',
                                    ),
                                  ),
                                  SizedBox(width: 6.sw),
                                  Icon(Icons.close_rounded, size: 16.sp, color: const Color(0xFFFFF2EA).withValues(alpha: 0.8)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : (_error != null)
                            ? _errorView()
                            : _listView(padBottom: 92 + safeBottom),
                  ),
                ],
              ),
            ),

            // Bottom CTA pinned (always visible)
            Positioned(
              left: 20.sw,
              right: 20.sw,
              bottom: 16.sh + safeBottom,
              child: SizedBox(
                height: 62.sh,
                child: ElevatedButton(
                  onPressed: () {
                    // Return selected ingredients to the previous screen (SearchScreen)
                    // Return exactly what is selected.
                    Navigator.pop(context, _selected.toList());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cta,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.sw)),
                    elevation: 0,
                  ),
                  child: Text(
                    "Done",
                    style: TextStyle(
                      color: const Color(0xFFFFF2EA),
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Satoshi',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.sw),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 50.sw,
              height: 50.sw,
              decoration: BoxDecoration(
                color: const Color(0xFFF9E3D5),
                borderRadius: BorderRadius.circular(25.sw),
              ),
              child: Icon(Icons.arrow_back_ios_new, size: 18.sw, color: primary),
            ),
          ),
          const Spacer(),
          // Optional: reload button
          IconButton(
            onPressed: () {
              setState(() {
                _selected.clear();
              });
              _loadCsv(DefaultAssetBundle.of(context));
            },
            icon: const Icon(Icons.refresh, color: primary),
          )
        ],
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          "Failed to load pantry data.\n\n$_error",
          textAlign: TextAlign.center,
          style: const TextStyle(color: primary, fontFamily: 'Satoshi'),
        ),
      ),
    );
  }

  Widget _listView({required double padBottom}) {
    // Build list of visible categories (those with matching items)
    final visibleCategories = <int>[];
    for (int i = 0; i < _categories.length; i++) {
      final meta = _categories[i];
      final allItems = _byCategory[meta.keyName] ?? const <String>[];
      final filteredItems = _searchQuery.isEmpty
          ? allItems
          : allItems.where((item) => item.toLowerCase().contains(_searchQuery)).toList();
      
      // Only include categories with items
      if (filteredItems.isNotEmpty) {
        visibleCategories.add(i);
      }
    }
    
    // Sort categories when searching: categories with better matches appear first
    if (_searchQuery.isNotEmpty && visibleCategories.isNotEmpty) {
      visibleCategories.sort((aIndex, bIndex) {
        final aMeta = _categories[aIndex];
        final bMeta = _categories[bIndex];
        final aItems = _byCategory[aMeta.keyName] ?? const <String>[];
        final bItems = _byCategory[bMeta.keyName] ?? const <String>[];
        
        // Check if category has exact match or starts-with match
        final aHasExactOrStarts = aItems.any((item) {
          final lower = item.toLowerCase();
          return lower == _searchQuery || lower.startsWith(_searchQuery);
        });
        final bHasExactOrStarts = bItems.any((item) {
          final lower = item.toLowerCase();
          return lower == _searchQuery || lower.startsWith(_searchQuery);
        });
        
        // Prioritize categories with exact/starts-with matches
        if (aHasExactOrStarts && !bHasExactOrStarts) return -1;
        if (!aHasExactOrStarts && bHasExactOrStarts) return 1;
        
        // Otherwise maintain original order
        return aIndex.compareTo(bIndex);
      });
    }
    
    final itemCount = visibleCategories.length;

    return ListView.separated(
      padding: EdgeInsets.only(left: 20.sw, right: 20.sw, bottom: padBottom),
      itemCount: itemCount,
      separatorBuilder: (_, __) => SizedBox(height: 16.sh),
      itemBuilder: (context, index) {
        final categoryIndex = visibleCategories[index];
        final meta = _categories[categoryIndex];
        final allItems = _byCategory[meta.keyName] ?? const <String>[];
        
        // Filter items based on search query
        var filteredItems = _searchQuery.isEmpty
            ? allItems
            : allItems.where((item) => item.toLowerCase().contains(_searchQuery)).toList();
        
        // Sort filtered items when searching: exact match > starts with > contains
        if (_searchQuery.isNotEmpty && filteredItems.isNotEmpty) {
          filteredItems.sort((a, b) {
            final aLower = a.toLowerCase();
            final bLower = b.toLowerCase();
            final query = _searchQuery;
            
            // Exact match
            final aExact = aLower == query;
            final bExact = bLower == query;
            if (aExact && !bExact) return -1;
            if (!aExact && bExact) return 1;
            
            // Starts with
            final aStarts = aLower.startsWith(query);
            final bStarts = bLower.startsWith(query);
            if (aStarts && !bStarts) return -1;
            if (!aStarts && bStarts) return 1;
            
            // Otherwise maintain alphabetical order
            return aLower.compareTo(bLower);
          });
        }
        
        final isExpanded = _expanded[meta.keyName] ?? false;
        final selectedInCategory = filteredItems.where((item) => _selected.contains(item)).length;
        final totalInCategory = filteredItems.length;

        return _StaggeredItem(
          index: index,
          child: _CategoryCard(
            meta: meta,
            subtitle: "$selectedInCategory/$totalInCategory ingredients",
            allItems: filteredItems,
            isExpanded: isExpanded || _searchQuery.isNotEmpty,
            isSelected: (s) => _selected.contains(s),
            onToggleChip: _toggleIngredient,
            onToggleExpansion: () => _toggleCategoryExpansion(meta.keyName),
            primary: primary,
            chipBg: chipBg,
            chipText: chipText,
            showExpandButton: _searchQuery.isEmpty,
          ),
        );
      },
    );
  }
}

class _StaggeredItem extends StatelessWidget {
  final Widget child;
  final int index;
  const _StaggeredItem({required this.child, required this.index});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (index * 50).clamp(0, 400)),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.95 + (0.05 * value),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _StaggeredChip extends StatelessWidget {
  final Widget child;
  final int index;
  const _StaggeredChip({required this.child, required this.index});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (index * 20).clamp(0, 300)),
      curve: Curves.easeOutBack,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.7 + (0.3 * value),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _CategoryMeta {
  final String keyName; // must match CSV category exactly
  final String title;
  final String iconAsset;
  const _CategoryMeta({required this.keyName, required this.title, required this.iconAsset});
}

class _CategoryCard extends StatelessWidget {
  final _CategoryMeta meta;
  final String subtitle;
  final List<String> allItems;
  final bool isExpanded;
  final bool showExpandButton;

  final bool Function(String) isSelected;
  final void Function(String) onToggleChip;
  final VoidCallback onToggleExpansion;

  final Color primary;
  final Color chipBg;
  final Color chipText;

  const _CategoryCard({
    required this.meta,
    required this.subtitle,
    required this.allItems,
    required this.isExpanded,
    required this.isSelected,
    required this.onToggleChip,
    required this.onToggleExpansion,
    required this.primary,
    required this.chipBg,
    required this.chipText,
    this.showExpandButton = true,
  });

  @override
  Widget build(BuildContext context) {
    
    // Logic for displaying items:
    // If expanded, show all.
    // If not expanded, show up to 6 items.
    // If > 6 items total, show 5 items + 1 "more" chip if collapsed.
    final totalCount = allItems.length;
    final hasMore = totalCount > 6;
    
    final displayLimit = (isExpanded || !hasMore) ? totalCount : 5;
    final displayItems = allItems.take(displayLimit).toList();

    return Container(
      padding: EdgeInsets.all(16.sw),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(24.sw),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Icon + Title/Subtitle
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Circular Icon
              Container(
                width: 78.sw,
                height: 78.sw,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha:0.25),
                  shape: BoxShape.circle,
                ),
                padding: EdgeInsets.all(14.sw),
                child: Image.asset(meta.iconAsset, fit: BoxFit.contain),
              ),
              SizedBox(width: 12.sw),
              
              // Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            meta.title,
                            style: TextStyle(
                              color: primary,
                              fontSize: 20.sp,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Satoshi',
                            ),
                          ),
                        ),
                        // Only show arrow if it has more items to expand/collapse
                        // or if currently expanded (to allow collapsing).
                        // Although "+more" handles expansion, arrow handles collapse.
                        if (hasMore && showExpandButton)
                          InkWell(
                            onTap: onToggleExpansion,
                            borderRadius: BorderRadius.circular(20.sw),
                            child: Padding(
                              padding: EdgeInsets.all(6.sw),
                              child: AnimatedRotation(
                                turns: isExpanded ? 0.5 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: const Color(0xFF462F4D),
                                  size: 24.sw,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 4.sh),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: const Color(0xFF462F4D),
                        fontSize: 12.sp,
                        fontFamily: 'Satoshi',
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 14.sh), // Spacing between header and chips

          // Chips Section
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: Alignment.topLeft,
            child: Wrap(
              spacing: 10.sw,
              runSpacing: 10.sh,
              children: [
                for (int i = 0; i < displayItems.length; i++)
                  _StaggeredChip(
                    index: i,
                    child: _PillChip(
                      label: displayItems[i],
                      selected: isSelected(displayItems[i]),
                      onTap: () => onToggleChip(displayItems[i]),
                      primary: primary,
                      chipBg: chipBg,
                      chipText: chipText,
                    ),
                  ),
              
              // Key change: "+more" chip
                if (!isExpanded && hasMore)
                _PillChip(
                  label: '+${totalCount - 5} more',
                  selected: false,
                  onTap: onToggleExpansion,
                  primary: primary,
                  chipBg: chipBg,
                  chipText: chipText,
                  border: Border.all(color: primary),
                ),
            ],
          ),
            ),
        ],
      ),
    );
  }
}

class _PillChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  final Color primary;
  final Color chipBg;
  final Color chipText;
  final BoxBorder? border;

  const _PillChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.primary,
    required this.chipBg,
    required this.chipText,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = selected ? primary : chipBg;
    final textColor = selected ? const Color(0xFFFFF2EA) : chipText;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.06 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(horizontal: 16.sw, vertical: 9.sh),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20.sw),
            border: border ?? Border.all(color: selected ? Colors.white24 : Colors.transparent),
            boxShadow: selected ? [
              BoxShadow(
                color: primary.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ] : null,
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            style: TextStyle(
              color: textColor,
              fontSize: 12.sp,
              fontFamily: 'Satoshi',
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

