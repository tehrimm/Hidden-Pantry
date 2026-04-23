import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_service.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:hidden_pantry_app/features/recipes/screens/recipe_details.dart';
import 'package:hidden_pantry_app/features/recipes/widgets/recipe_card.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';
import 'dart:math' as math;


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
  static const Color orange = Color(0xFFEF8A54);
  
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
    ResponsiveUtils.init(context);
    final double topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: widget.isNutritionist ? Colors.white : bg,
      body: ClipRRect(
        borderRadius: widget.isNutritionist ? BorderRadius.circular(30.sw) : BorderRadius.zero,
        child: Container(
          color: bg,
          child: Stack(
            children: [
              const PatternBackground(),

              // Decorative corner shapes
              ..._buildCornerDecorations(),

              // Standardized Header - Back Button
              Positioned(
                left: 30.sw,
                top: topPad + 36.sh,
                child: BackButtonWidget(
                  color: brown,
                  onPressed: () => Navigator.pop(context),
                ),
              ),

              // Standardized Header - Title
              Positioned(
                left: 0,
                right: 0,
                top: topPad + 36.sh,
                height: 50.sh,
                child: Center(
                  child: Text(
                    "My Favourites",
                    style: TextStyle(
                      color: purple,
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                      fontFamily: "Satoshi",
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: Column(
                  children: [
                    SizedBox(height: 96.sh), // Standardized gap for fixed header
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

  List<Widget> _buildCornerDecorations() {
    return [
      // Top-right circle
      Positioned(
        top: -30.sh,
        right: -30.sw,
        child: Container(
          width: 120.sw,
          height: 120.sw,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: orange.withValues(alpha: 0.06),
          ),
        ),
      ),
      // Bottom-left circle
      Positioned(
        bottom: -40.sh,
        left: -40.sw,
        child: Container(
          width: 160.sw,
          height: 160.sw,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: purple.withValues(alpha: 0.04),
          ),
        ),
      ),
      // Small accent dot top-left
      Positioned(
        top: 140.sh,
        left: 20.sw,
        child: Container(
          width: 12.sw,
          height: 12.sw,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: orange.withValues(alpha: 0.15),
          ),
        ),
      ),
      // Diamond shape mid-right
      Positioned(
        top: 260.sh,
        right: 16.sw,
        child: Transform.rotate(
          angle: math.pi / 4,
          child: Container(
            width: 18.sw,
            height: 18.sw,
            decoration: BoxDecoration(
              color: purple.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(4.sw),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: orange, strokeWidth: 2.5),
      );
    }

    if (_error != null) {
      return _FadeSlideEntry(
        delayMs: 200,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70.sw,
                height: 70.sw,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withValues(alpha: 0.08),
                ),
                child: Icon(Icons.error_outline, size: 36.sw, color: Colors.redAccent),
              ),
              SizedBox(height: 20.sh),
              Text(_error!, style: TextStyle(color: purple, fontFamily: 'Satoshi', fontSize: 15.sp)),
              SizedBox(height: 12.sh),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() { _loading = true; _error = null; });
                  _loadFavourites();
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 24.sw, vertical: 10.sh),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [orange, const Color(0xFFFFA06A)]),
                    borderRadius: BorderRadius.circular(14.sw),
                  ),
                  child: Text("Retry", style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w700, fontFamily: 'Satoshi')),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_recipes.isEmpty) {
      return _FadeSlideEntry(
        delayMs: 200,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 90.sw,
                height: 90.sw,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      orange.withValues(alpha: 0.15),
                      orange.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: orange.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(Icons.favorite_border_rounded, size: 40.sw, color: orange),
              ),
              SizedBox(height: 24.sh),
              Text(
                "No favourites yet",
                style: TextStyle(
                  color: purple,
                  fontFamily: "Satoshi",
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8.sh),
              Text(
                "Heart recipes to save them here!",
                style: TextStyle(
                  color: purple.withValues(alpha: 0.45),
                  fontFamily: "Satoshi",
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 30.sw),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 10.sh),
          // Count badge
          _FadeSlideEntry(
            delayMs: 100,
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.sw, vertical: 6.sh),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20.sw),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite_rounded, color: orange, size: 14.sw),
                      SizedBox(width: 6.sw),
                      Text(
                        "${_recipes.length} recipe${_recipes.length != 1 ? 's' : ''}",
                        style: TextStyle(
                          color: purple.withValues(alpha: 0.6),
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Satoshi',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20.sh),
          _FadeSlideEntry(
            delayMs: 200,
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 157 / 231,
                crossAxisSpacing: 15.sw,
                mainAxisSpacing: 15.sh,
              ),
              itemCount: _recipes.length,
              itemBuilder: (context, index) {
                final r = _recipes[index];
                return RecipeCard(
                  recipe: r,
                  isNutritionist: widget.isNutritionist,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => RecipeDetailsScreen(recipe: r)),
                    );
                  },
                );
              },
            ),
          ),
          SizedBox(height: 30.sh),
        ],
      ),
    );
  }
}

// ─── Staggered Fade+Slide Animation Widget ───
class _FadeSlideEntry extends StatefulWidget {
  final Widget child;
  final int delayMs;
  const _FadeSlideEntry({required this.child, this.delayMs = 0});

  @override
  State<_FadeSlideEntry> createState() => _FadeSlideEntryState();
}

class _FadeSlideEntryState extends State<_FadeSlideEntry> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}
