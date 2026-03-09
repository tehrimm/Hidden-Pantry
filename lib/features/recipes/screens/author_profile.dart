import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_api_service.dart';
import 'package:hidden_pantry_app/core/constants/api_constants.dart';
import 'package:hidden_pantry_app/features/recipes/screens/recipe_details.dart';
import 'package:hidden_pantry_app/features/user/services/follow_service.dart';
import 'package:hidden_pantry_app/features/recipes/widgets/recipe_card.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';


class AuthorProfileScreen extends StatefulWidget {
  final String authorId;
  final String authorName;
  final String? profileImageUrl;

  const AuthorProfileScreen({
    super.key,
    required this.authorId,
    required this.authorName,
    this.profileImageUrl,
  });

  @override
  State<AuthorProfileScreen> createState() => _AuthorProfileScreenState();
}

class _AuthorProfileScreenState extends State<AuthorProfileScreen> {
  static const Color bgColor = Color(0xFFFFF3EB);
  static const Color cardColor = Color(0xFFF9E3D5);
  static const Color textColor = Color(0xFF462F4D);
  static const Color orange = Color(0xFFEF8A54);

  final RecipeApiService _api = const RecipeApiService(baseUrl: ApiConstants.baseUrl);
  final FollowService _followService = FollowService();
  
  bool _loading = true;
  List<Recipe> _recipes = [];
  Map<String, dynamic> _stats = {};
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.getAuthorStats(widget.authorId).catchError((e) {
          print("[AuthorProfile] Stats error: $e");
          return <String, dynamic>{};
        }),
        _api.fetchRecipesByAuthor(widget.authorId, limit: 20).catchError((e) {
          print("[AuthorProfile] Recipes error: $e");
          return <Recipe>[];
        }),
        _fetchFirestoreRecipesByAuthor(widget.authorId).catchError((e) {
          print("[AuthorProfile] Firestore recipes error: $e");
          return <Recipe>[];
        }),
        _followService.isFollowing(widget.authorId).catchError((e) {
          print("[AuthorProfile] Follow check error: $e");
          return false;
        }),
        _followService.getPublicAuthorStats(widget.authorId).catchError((e) {
          print("[AuthorProfile] Firestore stats error: $e");
          return {'followers': 0, 'following': 0};
        }),
        _fetchFirestoreAuthorStats(widget.authorId),
      ]);

      if (mounted) {
        setState(() {
          _stats = results[0] as Map<String, dynamic>;
          final apiRecipes = results[1] as List<Recipe>;
          final fsRecipes = results[2] as List<Recipe>;
          final byId = <String, Recipe>{};
          for (final r in [...apiRecipes, ...fsRecipes]) {
            if (r.id.isNotEmpty && r.isPublic) byId[r.id] = r;
          }
          _recipes = byId.values.toList();
          _stats['recipe_count'] = _recipes.length;
          _isFollowing = results[3] as bool;                                  

          final firestoreFollowStats = results[4] as Map<String, int>;        
          final firestoreMetricStats = results[5] as Map<String, dynamic>;    

          // Override API mocked stats with real Firestore stats
          _stats['followers'] = firestoreFollowStats['followers'];
          _stats['following'] = firestoreFollowStats['following'];
          
          // NEW: Add live aggregate metrics
          if (firestoreMetricStats.containsKey('recipe_count')) {
            _stats['recipe_count'] = firestoreMetricStats['recipe_count'];
          }
          if (firestoreMetricStats.containsKey('avg_rating')) {
            _stats['avg_rating'] = firestoreMetricStats['avg_rating'];
          }

          _loading = false;
        });
      }
    } catch (e) {
      print("[AuthorProfile] Error loading data: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Map<String, dynamic>> _fetchFirestoreAuthorStats(String authorId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      var doc = await firestore.collection('nutritionists').doc(authorId).get();
      if (!doc.exists) {
        doc = await firestore.collection('users').doc(authorId).get();
      }
      if (!doc.exists) return {};
      
      final data = doc.data()!;
      final int recipeCount = int.tryParse(data['recipe_count']?.toString() ?? '0') ?? 0;
      final double ratingSum = double.tryParse(data['total_rating_sum']?.toString() ?? '0') ?? 0.0;
      final int reviewCount = int.tryParse(data['total_review_count']?.toString() ?? '0') ?? 0;
      
      double avgRating = 0.0;
      if (reviewCount > 0) {
        avgRating = ratingSum / reviewCount;
      }
      
      return {
        'recipe_count': recipeCount,
        'avg_rating': avgRating > 0 ? avgRating.toStringAsFixed(1) : "0.0",
      };
    } catch (e) {
      print("[AuthorProfile] Error fetching Firestore metrics: $e");
      return {};
    }
  }

  Future<List<Recipe>> _fetchFirestoreRecipesByAuthor(String authorId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('recipes')
          .where('author_id', isEqualTo: authorId)
          .where('is_public', isEqualTo: true)
          .get();
      return snap.docs.map((d) => Recipe.fromJson(d.data())).toList();
    } catch (e) {
      print("[AuthorProfile] Error fetching Firestore recipes for author $authorId: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          const PatternBackground(),
                // Standardized Header - Back Button
                Positioned(
                  left: 30.sw,
                  top: 51.sh,
                  child: const BackButtonWidget(color: textColor),
                ),

                SafeArea(
                  child: Column(
                    children: [
                      SizedBox(height: 70.sh), // Gap for standardized header

                Expanded(
                  child: _loading 
                    ? const Center(child: CircularProgressIndicator(color: orange))
                    : _buildContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 18.sw),
      child: Column(
        children: [
          SizedBox(height: 10.sh),
          
          // Profile Photo (Centered)
          Center(
            child: Container(
              width: 120.sw,
              height: 120.sw,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4.sw),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha:0.05), blurRadius: 10.sw, spreadRadius: 2.sw),
                ],
              ),
              child: ClipOval(
                child: widget.profileImageUrl != null && widget.profileImageUrl!.isNotEmpty
                  ? Image.network(widget.profileImageUrl!, fit: BoxFit.cover, errorBuilder: (_,__,___) => _fallbackAvatar())
                  : _fallbackAvatar(),
              ),
            ),
          ),

          SizedBox(height: 16.sh),

          // Name
          Text(
            widget.authorName,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontSize: 24.sp,
              fontWeight: FontWeight.w800,
              fontFamily: "Satoshi",
            ),
          ),

          SizedBox(height: 16.sh),

          // Follow Button
          SizedBox(
            width: 140.sw,
            height: 44.sh,
            child: ElevatedButton(
              onPressed: () async {
                final newValue = !_isFollowing;
                setState(() {
                  _isFollowing = newValue;
                  // Local optimistic update for stats
                  if (_stats.containsKey('followers')) {
                    int current = _stats['followers'] is int 
                      ? _stats['followers'] 
                      : int.tryParse(_stats['followers'].toString()) ?? 0;
                    _stats['followers'] = newValue ? current + 1 : (current - 1).clamp(0, double.infinity).toInt();
                  }
                });
                await _followService.toggleFollow(
                  widget.authorId, 
                  shouldFollow: newValue,
                  authorName: widget.authorName,
                  photoUrl: widget.profileImageUrl,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _isFollowing ? Colors.white : orange,
                foregroundColor: _isFollowing ? orange : Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22.sw),
                  side: _isFollowing ? const BorderSide(color: orange) : BorderSide.none,
                ),
              ),
              child: Text(
                _isFollowing ? "Following" : "Follow",
                style: TextStyle(fontWeight: FontWeight.w800, fontFamily: "Satoshi", fontSize: 14.sp),
              ),
            ),
          ),

          SizedBox(height: 28.sh),

          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _statItem("Recipes", _stats['recipe_count']?.toString() ?? "0"),
              _statItem("Followers", _stats['followers']?.toString() ?? "0"),
              _statItem("Following", _stats['following']?.toString() ?? "0"),
              if (_stats['avg_rating'] != null && _stats['avg_rating'] != "0.0")
                _statItem("Rating", _stats['avg_rating']?.toString() ?? "0.0"),
            ],
          ),

          SizedBox(height: 32.sh),

          // Recipes Header
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Posted Recipes",
              style: TextStyle(
                color: textColor,
                fontSize: 20.sp,
                fontWeight: FontWeight.w800,
                fontFamily: "Satoshi",
              ),
            ),
          ),

          SizedBox(height: 16.sh),

          // Recipes Grid or List
          if (_recipes.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 40.sh),
              child: Text("No recipes posted yet.", style: TextStyle(color: textColor.withValues(alpha:0.5), fontSize: 14.sp)),
            )
          else
            _buildRecipeGrid(),
          
          SizedBox(height: 40.sh),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            fontFamily: "Satoshi",
          ),
        ),
        SizedBox(height: 4.sh),
        Text(
          label,
          style: TextStyle(
            color: textColor.withValues(alpha:0.5),
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
            fontFamily: "Satoshi",
          ),
        ),
      ],
    );
  }

  Widget _buildRecipeGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 157 / 231, // Standard aspect ratio for cards
        crossAxisSpacing: 16.sw,
        mainAxisSpacing: 16.sh,
      ),
      itemCount: _recipes.length,
      itemBuilder: (context, index) {
        final r = _recipes[index];
        return RecipeCard(
          recipe: r,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => RecipeDetailsScreen(recipe: r)),
            );
          },
        );
      },
    );
  }

  Widget _fallbackAvatar() {
    return Container(
      color: cardColor,
      child: Icon(Icons.person, size: 50.sw, color: orange),
    );
  }

  
}
