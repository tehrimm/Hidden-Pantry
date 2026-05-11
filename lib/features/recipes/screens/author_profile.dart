import 'package:firebase_auth/firebase_auth.dart';
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
import 'package:hidden_pantry_app/core/widgets/skeletons.dart';
import 'package:hidden_pantry_app/core/services/moderation_service.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';



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

  int _limit = 20;
  bool _loadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() {
      _loadingMore = true;
      _limit += 10;
    });
    await _loadData(isLoadMore: true);
  }

  Future<void> _loadData({bool isLoadMore = false}) async {
    if (!isLoadMore) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.getAuthorStats(widget.authorId).catchError((e) {
          print("[AuthorProfile] Stats error: $e");
          return <String, dynamic>{};
        }),
        _api.fetchRecipesByAuthor(widget.authorId, limit: _limit).catchError((e) {
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
          final currentUid = FirebaseAuth.instance.currentUser?.uid;
          for (final r in [...apiRecipes, ...fsRecipes]) {
            if (r.id.isNotEmpty && (r.isPublic || widget.authorId == currentUid)) byId[r.id] = r;
          }
          final combinedList = byId.values.toList();
          if (isLoadMore) {
            final existingIds = _recipes.map((r) => r.id).toSet();
            final actuallyNew = combinedList.where((r) => !existingIds.contains(r.id)).toList();
            _recipes.addAll(actuallyNew);
            _loadingMore = false;
          } else {
            _recipes = combinedList;
            _loading = false;
          }

          // 🛡️ Ensure recipe count is accurate if metadata is missing or 0
          final dynamic rawCount = _stats['recipe_count'];
          bool countIsZero = rawCount == null || 
                            (rawCount is int && rawCount == 0) || 
                            (rawCount is String && (rawCount == '0' || rawCount.isEmpty));
          
          if (countIsZero && _recipes.isNotEmpty) {
            _stats['recipe_count'] = _recipes.length;
          }
          _isFollowing = results[3] as bool;                                  

          final firestoreFollowStats = results[4] as Map<String, int>;        
          final firestoreMetricStats = results[5] as Map<String, dynamic>;    


          _stats['followers'] = firestoreFollowStats['followers'];
          _stats['following'] = firestoreFollowStats['following'];
          
          
          if (firestoreMetricStats.containsKey('recipe_count') && (firestoreMetricStats['recipe_count'] as int) > 0) {
            _stats['recipe_count'] = firestoreMetricStats['recipe_count'];
          }
          if (firestoreMetricStats.containsKey('avg_rating')) {
            _stats['avg_rating'] = firestoreMetricStats['avg_rating'];
          }
          
          if (_recipes.length < _limit) _hasMore = false;
        });
      }
    } catch (e) {
      print("[AuthorProfile] Error loading data: $e");
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
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
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final query = FirebaseFirestore.instance
          .collection('recipes')
          .where('author_id', isEqualTo: authorId);
      
      final snap = (authorId == currentUid) 
        ? await query.get() 
        : await query.where('is_public', isEqualTo: true).get();
        
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
                
                // Block/More Button
                Positioned(
                  right: 30.sw,
                  top: 51.sh,
                  child: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, color: textColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.sw)),
                    onSelected: (value) {
                      if (value == 'block') {
                        _showBlockConfirm(context);
                      } else if (value == 'report') {
                         _showReportDialog(context);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'report',
                        child: Row(
                          children: [
                            Icon(Icons.report_problem_outlined, color: Colors.orange, size: 20.sw),
                            SizedBox(width: 10.sw),
                            const Text("Report User", style: TextStyle(fontFamily: "Satoshi")),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'block',
                        child: Row(
                          children: [
                            Icon(Icons.block_flipped, color: Colors.red, size: 20.sw),
                            SizedBox(width: 10.sw),
                            const Text("Block User", style: TextStyle(fontFamily: "Satoshi")),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),


                SafeArea(
                  child: Column(
                    children: [
                      SizedBox(height: 70.sh), // Gap for standardized header

                Expanded(
                  child: _loading 
                    ? Column(
                        children: [
                          SizedBox(height: 10.sh),
                          // Subtle top loader
                          SizedBox(
                            width: 20.sw,
                            height: 20.sw,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(orange),
                            ),
                          ),
                          SizedBox(height: 20.sh),
                          const Expanded(child: _ProfileSkeleton()),
                        ],
                      )
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

          // Follow Button (Hidden if viewing own profile)
          if (FirebaseAuth.instance.currentUser?.uid != widget.authorId)
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
              if (_stats['avg_rating'] != null && 
                  _stats['avg_rating'].toString() != "0.0" && 
                  _stats['avg_rating'].toString() != "0")
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
          else ...[
            _buildRecipeGrid(),
            if (_hasMore)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 20.sh),
                child: Center(
                  child: _loadingMore
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: orange),
                        )
                      : GestureDetector(
                          onTap: _loadMore,
                          child: Text(
                            "Load 10 more recipes",
                            style: TextStyle(
                              color: orange,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                              fontFamily: "Satoshi",
                              decoration: TextDecoration.underline,
                              decorationColor: orange,
                            ),
                          ),
                        ),
                ),
              ),
          ],
          
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
        childAspectRatio: 157 / 250, // Standard aspect ratio for cards
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

  void _showBlockConfirm(BuildContext context) {

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Block User?", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontFamily: "Satoshi")),
        content: const Text("You will no longer see content from this user. This action cannot be easily undone from the app."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await ModerationService().blockUser(widget.authorId);
              if (context.mounted) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back from profile
                Toaster.show(context, "${widget.authorName} has been blocked.");
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("Block"),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    String selectedReason = 'Spam';
    final List<String> reasons = ['Spam', 'Inappropriate Content', 'Harassment', 'False Information', 'Other'];
    final TextEditingController detailsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: bgColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Report User", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontFamily: "Satoshi")),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: selectedReason,
                isExpanded: true,
                items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (val) => setDialogState(() => selectedReason = val!),
              ),
              TextField(
                controller: detailsController,
                decoration: const InputDecoration(hintText: "Additional details (optional)"),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                await ModerationService().reportContent(
                  contentType: 'user',
                  contentId: widget.authorId,
                  authorId: widget.authorId,
                  reason: selectedReason,
                  additionalDetails: detailsController.text,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  Toaster.show(context, "Thank you. We have received your report.");
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text("Submit Report"),
            ),
          ],
        ),
      ),
    );
  }
}


class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 18.sw),
      child: Column(
        children: [
          SizedBox(height: 10.sh),
          // Avatar
          Center(
            child: SkeletonBox(
              width: 120.sw,
              height: 120.sw,
              borderRadius: BorderRadius.circular(60.sw),
            ),
          ),
          SizedBox(height: 16.sh),
          // Name Bar
          SkeletonBox(width: 180.sw, height: 28.sh),
          SizedBox(height: 16.sh),
          // Follow Button Bar
          SkeletonBox(
            width: 140.sw, 
            height: 44.sh,
            borderRadius: BorderRadius.circular(22.sw),
          ),
          SizedBox(height: 28.sh),
          // Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(4, (i) => Column(
              children: [
                SkeletonBox(width: 40.sw, height: 22.sh),
                SizedBox(height: 4.sh),
                SkeletonBox(width: 60.sw, height: 14.sh),
              ],
            )),
          ),
          SizedBox(height: 32.sh),
          // Grid Header
          Align(
            alignment: Alignment.centerLeft,
            child: SkeletonBox(width: 150.sw, height: 24.sh),
          ),
          SizedBox(height: 16.sh),
          // Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 157 / 250,
              crossAxisSpacing: 16.sw,
              mainAxisSpacing: 16.sh,
            ),
            itemCount: 4,
            itemBuilder: (_, __) => SkeletonBox(
              width: double.infinity,
              height: double.infinity,
              borderRadius: BorderRadius.circular(20.sw),
            ),
          ),
        ],
      ),
    );
  }
}
