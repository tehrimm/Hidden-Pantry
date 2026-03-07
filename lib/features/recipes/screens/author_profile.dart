import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_api_service.dart';
import 'package:hidden_pantry_app/core/constants/api_constants.dart';
import 'package:hidden_pantry_app/features/recipes/screens/recipe_details.dart';
import 'package:hidden_pantry_app/features/user/services/follow_service.dart';

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
          _recipes = results[1] as List<Recipe>;
          _isFollowing = results[2] as bool;
          
          final firestoreFollowStats = results[3] as Map<String, int>;
          final firestoreMetricStats = results[4] as Map<String, dynamic>;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          const PatternBackground(),
                // Standardized Header - Back Button
                Positioned(
                  left: 30,
                  top: 51,
                  child: const BackButtonWidget(color: textColor),
                ),

                SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 70), // Gap for standardized header

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
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        children: [
          const SizedBox(height: 10),
          
          // Profile Photo (Centered)
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha:0.05), blurRadius: 10, spreadRadius: 2),
                ],
              ),
              child: ClipOval(
                child: widget.profileImageUrl != null && widget.profileImageUrl!.isNotEmpty
                  ? Image.network(widget.profileImageUrl!, fit: BoxFit.cover, errorBuilder: (_,__,___) => _fallbackAvatar())
                  : _fallbackAvatar(),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Name
          Text(
            widget.authorName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: textColor,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              fontFamily: "Satoshi",
            ),
          ),

          const SizedBox(height: 16),

          // Follow Button
          SizedBox(
            width: 140,
            height: 44,
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
                  borderRadius: BorderRadius.circular(22),
                  side: _isFollowing ? const BorderSide(color: orange) : BorderSide.none,
                ),
              ),
              child: Text(
                _isFollowing ? "Following" : "Follow",
                style: const TextStyle(fontWeight: FontWeight.w800, fontFamily: "Satoshi"),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _statItem("Recipes", _stats['recipe_count']?.toString() ?? "0"),
              _statItem("Followers", _stats['followers']?.toString() ?? "0"),
              _statItem("Following", _stats['following']?.toString() ?? "0"),
              _statItem("Rating", _stats['avg_rating']?.toString() ?? "0.0"),
            ],
          ),

          const SizedBox(height: 32),

          // Recipes Header
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Posted Recipes",
              style: TextStyle(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                fontFamily: "Satoshi",
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Recipes Grid or List
          if (_recipes.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Text("No recipes posted yet.", style: TextStyle(color: textColor.withValues(alpha:0.5))),
            )
          else
            _buildRecipeGrid(),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            fontFamily: "Satoshi",
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: textColor.withValues(alpha:0.5),
            fontSize: 12,
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
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _recipes.length,
      itemBuilder: (context, index) {
        final r = _recipes[index];
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
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(color: cardColor),
                    child: r.imageUrl != null && r.imageUrl!.startsWith("http")
                      ? Image.network(r.imageUrl!, fit: BoxFit.cover, errorBuilder: (_,__,___) => _fallbackRecipe())
                      : _fallbackRecipe(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                r.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  fontFamily: "Satoshi",
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _fallbackAvatar() {
    return Container(
      color: cardColor,
      child: const Icon(Icons.person, size: 50, color: orange),
    );
  }

  Widget _fallbackRecipe() {
    return Image.asset('assets/Logos/recipe_placeholder.jpg', fit: BoxFit.cover);
  }
}
