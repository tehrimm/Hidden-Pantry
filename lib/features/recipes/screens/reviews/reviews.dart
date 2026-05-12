import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/core/widgets/skeletons.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_service.dart';
import 'package:hidden_pantry_app/core/services/moderation_service.dart';
import 'post_review.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';


class ReviewsScreen extends StatefulWidget {
  final Recipe recipe;
  final RecipeService? recipeService;

  const ReviewsScreen({super.key, required this.recipe, this.recipeService});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  late final RecipeService _rs;
  late final Stream<QuerySnapshot> _reviewsStream;
  Set<String> _blockedUserIds = {};

  @override
  void initState() {
    super.initState();
    _rs = widget.recipeService ?? RecipeService();
    _reviewsStream = _rs.getReviews(widget.recipe.id);
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    try {
      final blocked = await ModerationService().getBlockedUsers();
      if (mounted) {
        setState(() {
          _blockedUserIds = blocked.toSet();
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    const Color bg = Color(0xFFFFF3EB);
    const Color purple = Color(0xFF462F4D);
    const Color orange = Color(0xFFEF8A54);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          const PatternBackground(),
          
          // Custom Header
          Positioned(
            left: 30.sw,
            top: 51.sh,
            child: BackButtonWidget(color: purple),
          ),
          
          Positioned(
            left: 90.sw,
            top: 51.sh,
            right: 30.sw,
            height: 50.sh,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Tips & Photos",
                  style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 18.sp, fontFamily: "Satoshi"),
                ),
                Text(
                  widget.recipe.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: purple.withValues(alpha:0.5), fontSize: 12.sp, fontFamily: "Satoshi"),
                ),
              ],
            ),
          ),

          Positioned.fill(
            top: 110.sh,
            child: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _reviewsStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return ListView.builder(
                            padding: EdgeInsets.symmetric(horizontal: 22.sw, vertical: 10.sh),
                            itemCount: 5,
                            itemBuilder: (context, index) => Padding(
                              padding: EdgeInsets.only(bottom: 16.sh),
                              child: SkeletonBox(
                                width: double.infinity,
                                height: 120.sh,
                                glassy: true,
                              ),
                            ),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(child: Text("Error: ${snapshot.error}"));
                        }
                        var docs = snapshot.data?.docs ?? [];
                        if (_blockedUserIds.isNotEmpty) {
                          docs = docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return !_blockedUserIds.contains(data['userId']);
                          }).toList();
                        }
                        
                        if (docs.isEmpty) {
                          return ListView(
                            padding: EdgeInsets.symmetric(horizontal: 22.sw, vertical: 10.sh),
                            children: [
                              Padding(
                                padding: EdgeInsets.only(top: 40.sh),
                                child: _buildEmptyState(context, orange, purple),
                              ),
                            ],
                          );
                        }

                        return ListView.builder(
                          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                          padding: EdgeInsets.symmetric(horizontal: 22.sw, vertical: 10.sh),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data = doc.data() as Map<String, dynamic>;
                            return Padding(
                              padding: EdgeInsets.only(bottom: 16.sh),
                              child: _StaggeredItem(
                                index: index,
                                child: _ReviewCard(
                                  key: ValueKey(doc.id),
                                  reviewId: doc.id,
                                  data: data,
                                  purple: purple,
                                  orange: orange,
                                  recipeService: _rs,
                                  blockedUserIds: _blockedUserIds,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  
                  // Sticky Add Review Bar
                  Container(
                    padding: EdgeInsets.all(16.sw),
                    decoration: BoxDecoration(
                      color: bg,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha:0.05),
                          blurRadius: 10.sw,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: _buildAddReviewPrompt(context, widget.recipe, purple, orange),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildAddReviewPrompt(BuildContext context, Recipe recipe, Color purple, Color orange) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    final reviewId = "${user.uid}_${recipe.id}";
    final reviewDocStream = FirebaseFirestore.instance.collection('reviews').doc(reviewId).snapshots();
    return StreamBuilder<DocumentSnapshot>(
      stream: reviewDocStream,
      builder: (context, reviewSnap) {
        if (reviewSnap.connectionState == ConnectionState.waiting) {
          return SizedBox(height: 50.sh, child: const Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        final hasReviewed = reviewSnap.data?.exists ?? false;

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
          builder: (context, userSnap) {
            final userData = userSnap.data?.data() as Map<String, dynamic>? ?? {};
            final userName = userData['fullName'] ?? user.displayName ?? "You";
            final userImageUrl = userData['photoUrl'] ?? user.photoURL ?? "";

            return GestureDetector(
              onTap: hasReviewed 
                ? null 
                : () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PostReviewScreen(recipe: recipe)),
                    );
                  },
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18.sw,
                    backgroundColor: purple.withValues(alpha:0.1),
                    backgroundImage: (userImageUrl.trim().isNotEmpty && userImageUrl.startsWith("http")) ? NetworkImage(userImageUrl) : null,
                    onBackgroundImageError: (userImageUrl.trim().isNotEmpty && userImageUrl.startsWith("http")) ? (_, __) {} : null,
                    child: Icon(Icons.person_rounded, color: purple, size: 18.sp),
                  ),
                  SizedBox(width: 12.sw),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16.sw, vertical: 10.sh),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20.sw),
                        border: Border.all(color: purple.withValues(alpha:0.1)),
                      ),
                      child: Text(
                        hasReviewed 
                          ? "You have already rated this recipe."
                          : "Add a review as $userName...",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: hasReviewed ? purple.withValues(alpha:0.7) : purple.withValues(alpha:0.4), 
                          fontSize: 12.sp, 
                          fontFamily: "Satoshi",
                          fontWeight: hasReviewed ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, Color orange, Color purple) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mode_comment_outlined, size: 64.sp, color: purple.withValues(alpha:0.3)),
          SizedBox(height: 16.sh),
          Text(
            "No reviews yet.",
            style: TextStyle(color: purple, fontSize: 18.sp, fontWeight: FontWeight.bold, fontFamily: "Satoshi"),
          ),
          SizedBox(height: 8.sh),
          Text(
            "Be the first to share your thoughts!",
            style: TextStyle(color: purple.withValues(alpha:0.6), fontFamily: "Satoshi", fontSize: 14.sp),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatefulWidget {
  final String reviewId;
  final Map<String, dynamic> data;
  final Color purple;
  final Color orange;
  final RecipeService recipeService;
  final Set<String> blockedUserIds;

  const _ReviewCard({
    super.key,
    required this.reviewId,
    required this.data,
    required this.purple,
    required this.orange,
    required this.recipeService,
    required this.blockedUserIds,
  });

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  bool _showReplyInput = false;
  bool _showReplies = true;
  bool _isSubmitting = false;
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  String? _fetchedUserName;
  String? _fetchedUserImageUrl;

  @override
  void initState() {
    super.initState();
    // If name/image missing, fetch them
    if (widget.data['userName'] == null || widget.data['userImageUrl'] == null) {
      _fetchPosterDetails();
    }
  }

  Future<void> _fetchPosterDetails() async {
    final userId = widget.data['userId'] as String?;
    if (userId == null) return;
    
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _fetchedUserName = data['fullName'];
          _fetchedUserImageUrl = data['photoUrl'];
        });
      }
    } catch (_) {
    }
  }

  void _replyToUser(String name) {
    if (FirebaseAuth.instance.currentUser == null) {
      Toaster.show(context, "Please login to reply.", isError: true);
      return;
    }
    setState(() {
      _showReplyInput = true;
      _showReplies = true; // Make sure they can see where it's going
      if (!_replyController.text.contains("@$name")) {
        _replyController.text = "@$name ${_replyController.text}".trim() + " ";
      }
    });
    
    // Small delay to ensure TextField is rendered before requesting focus
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && _focusNode.canRequestFocus) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _replyController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _reportReview(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Toaster.show(context, "Please login to report content.", isError: true);
      return;
    }

    try {
      await ModerationService().reportContent(
        contentType: 'review',
        contentId: widget.reviewId,
        authorId: widget.data['userId'] ?? '',
        reason: 'Community Guideline Violation',
      );
      if (context.mounted) {
        Toaster.show(context, "Review reported. Thank you for keeping the community safe.");
      }
    } catch (e) {
      if (context.mounted) {
        Toaster.show(context, "Error reporting review: $e", isError: true);
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      barrierDismissible: true,
      barrierLabel: 'Delete Review',
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: Curves.easeOutBack.transform(anim1.value),
          child: Opacity(
            opacity: anim1.value,
            child: child,
          ),
        );
      },
      pageBuilder: (context, anim1, anim2) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: const Color(0xFFFFF3EB).withValues(alpha: 0.8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30.sw),
            side: const BorderSide(color: Colors.white, width: 1.5),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28.sw),
              SizedBox(width: 10.sw),
              Text(
                "Delete Review",
                style: TextStyle(color: widget.purple, fontWeight: FontWeight.w900, fontFamily: "Satoshi", fontSize: 18.sp),
              ),
            ],
          ),
          content: Text(
            "Are you sure you want to delete your review? This will also revert your rating for this recipe.",
            style: TextStyle(color: widget.purple.withValues(alpha: 0.8), fontFamily: "Satoshi", fontSize: 14.sp),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text("Cancel", style: TextStyle(color: widget.purple, fontWeight: FontWeight.bold, fontSize: 14.sp)),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10.sw),
              ),
              child: TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text("Delete", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14.sp)),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final recipeId = widget.data['recipeId'] ?? "";
      if (recipeId.isEmpty) return;

      try {
        await widget.recipeService.deleteReview(recipeId, user.uid);
        if (mounted) {
          Toaster.show(context, "Review deleted successfully.");
        }
      } catch (e) {
        if (mounted) {
          Toaster.show(context, "Error deleting review: $e", isError: true);
        }
      }
    }
  }

  Future<void> _submitReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Toaster.show(context, "Please login to reply.", isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Fetch current user details for the reply
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      
      await widget.recipeService.addReply(widget.reviewId, {
        'userId': user.uid,
        'userName': userData['fullName'] ?? user.displayName ?? "User",
        'userImageUrl': userData['photoUrl'] ?? user.photoURL ?? "",
        'comment': text,
      });

      if (mounted) {
        _replyController.clear();
        setState(() {
          _showReplyInput = false;
          _isSubmitting = false;
        });
        Toaster.show(context, "Reply posted!");
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        Toaster.show(context, "Error posting reply: $e", isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final rating = (widget.data['rating'] as num?)?.toDouble() ?? 5.0;
    final comment = widget.data['comment'] ?? "";
    final imageUrl = widget.data['imageUrl'] as String?;
    final createdAt = widget.data['createdAt'] as Timestamp?;
    final dateStr = createdAt != null ? _formatDate(createdAt.toDate()) : "";
    
    final userName = widget.data['userName'] ?? _fetchedUserName ?? "User";
    final userImageUrl = widget.data['userImageUrl'] ?? _fetchedUserImageUrl;
    
    final likes = (widget.data['likes'] as num?)?.toInt() ?? 0;
    final likedBy = List<String>.from(widget.data['likedBy'] ?? []);
    final isLiked = user != null && likedBy.contains(user.uid);
    final hasImage = userImageUrl != null && 
                    userImageUrl.toString().trim().isNotEmpty && 
                    userImageUrl.toString().startsWith("http");

    return Container(
      padding: EdgeInsets.all(16.sw),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9F5),
        borderRadius: BorderRadius.circular(20.sw),
        boxShadow: [
          BoxShadow(
            color: widget.purple.withValues(alpha: 0.03),
            blurRadius: 15.sw,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: User Info + Date
          Row(
            children: [
              CircleAvatar(
                radius: 18.sw,
                backgroundColor: widget.purple.withValues(alpha:0.1),
                backgroundImage: hasImage ? NetworkImage(userImageUrl.toString()) : null,
                onBackgroundImageError: hasImage ? (_, __) {} : null,
                child: Icon(Icons.person_rounded, color: widget.purple, size: 18.sp),
              ),
              SizedBox(width: 12.sw),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: widget.purple, fontWeight: FontWeight.bold, fontSize: 14.sp, fontFamily: "Satoshi"),
                    ),
                    Text(
                      dateStr,
                      style: TextStyle(color: widget.purple.withValues(alpha:0.5), fontSize: 11.sp, fontFamily: "Satoshi"),
                    ),
                  ],
                ),
              ),
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < rating.floor() ? Icons.star : (i < rating ? Icons.star_half : Icons.star_border),
                    color: widget.orange,
                    size: 14.sp,
                  );
                }),
              ),
            ],
          ),
              
          if (comment.isNotEmpty) ...[
            SizedBox(height: 12.sh),
            _buildCommentWithMentions(comment, widget.purple, widget.orange, 14.sp),
          ],
          
          if (imageUrl != null && imageUrl.isNotEmpty) ...[
            SizedBox(height: 12.sh),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _FullScreenGallery(imageUrl: imageUrl, heroTag: "review_photo_${widget.reviewId}"),
                  ),
                );
              },
              child: Hero(
                tag: "review_photo_${widget.reviewId}",
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15.sw),
                  child: Image.network(
                    imageUrl,
                    width: double.infinity,
                    height: 180.sh,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(),
                  ),
                ),
              ),
            ),
          ],
          
          // Only add this gap if we had content above to push away from the action row
          if (comment.isNotEmpty || (imageUrl != null && imageUrl.isNotEmpty))
            SizedBox(height: 12.sh)
          else
            SizedBox(height: 4.sh), // Much smaller gap if minimal review
          
          // Actions: Like, Reply & Delete
          Row(
            children: [
              _AnimatedLikeButton(
                isLiked: isLiked,
                likes: likes,
                purple: widget.purple,
                orange: widget.orange,
                onTap: user == null ? null : () => widget.recipeService.toggleLike(widget.reviewId, user.uid),
              ),
              SizedBox(width: 24.sw),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _replyToUser(userName),
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 18.sp, color: widget.purple.withValues(alpha:0.6)),
                    SizedBox(width: 6.sw),
                    Text(
                      "Reply",
                      style: TextStyle(
                        color: widget.purple.withValues(alpha:0.6),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        fontFamily: "Satoshi",
                      ),
                    ),
                  ],
                ),
              ),
              if (user != null && widget.data['userId'] == user.uid) ...[
                const Spacer(),
                GestureDetector(
                  onTap: () => _confirmDelete(context),
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: widget.purple.withValues(alpha:0.6), size: 18.sp),
                      SizedBox(width: 6.sw),
                      Text(
                        "Delete",
                        style: TextStyle(
                          color: widget.purple.withValues(alpha:0.6),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          fontFamily: "Satoshi",
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (user != null && (widget.data['userId'] != user.uid || user.email == "hiddenpantry.support@gmail.com")) ...[
                const Spacer(),
                GestureDetector(
                  onTap: () => _reportReview(context),
                  child: Row(
                    children: [
                      Icon(Icons.report_gmailerrorred_rounded, color: Colors.redAccent.withValues(alpha:0.6), size: 18.sp),
                      SizedBox(width: 6.sw),
                      Text(
                        "Report",
                        style: TextStyle(
                          color: Colors.redAccent.withValues(alpha:0.6),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          fontFamily: "Satoshi",
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          
          // Reply Input
          if (_showReplyInput) ...[
            SizedBox(height: 12.sh),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    focusNode: _focusNode,
                    enabled: !_isSubmitting,
                    decoration: InputDecoration(
                      hintText: "Write a reply...",
                      hintStyle: TextStyle(fontSize: 12.sp, color: widget.purple.withValues(alpha:0.4)),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12.sw, vertical: 8.sh),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.sw), borderSide: BorderSide(color: widget.purple.withValues(alpha:0.1))),
                    ),
                    style: TextStyle(fontSize: 13.sp, fontFamily: "Satoshi"),
                  ),
                ),
                if (_isSubmitting)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.sw),
                    child: SizedBox(width: 20.sw, height: 20.sw, child: CircularProgressIndicator(strokeWidth: 2, color: widget.orange)),
                  )
                else
                  IconButton(
                    onPressed: _submitReply,
                    icon: Icon(Icons.send, color: widget.orange, size: 20.sp),
                  ),
              ],
            ),
          ],
          
          // Replies List section
          StreamBuilder<QuerySnapshot>(
            stream: widget.recipeService.getReplies(widget.reviewId),
            builder: (context, snapshot) {
              var replies = snapshot.data?.docs ?? [];
              if (widget.blockedUserIds.isNotEmpty) {
                replies = replies.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return !widget.blockedUserIds.contains(data['userId']);
                }).toList();
              }
              
              if (replies.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 12.sh),
                  GestureDetector(
                    onTap: () => setState(() => _showReplies = !_showReplies),
                    child: Text(
                      _showReplies ? "Hide replies" : "View ${replies.length} replies",
                      style: TextStyle(color: widget.orange, fontWeight: FontWeight.bold, fontSize: 12.sp, fontFamily: "Satoshi"),
                    ),
                  ),
                  if (_showReplies) 
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: replies.length,
                      itemBuilder: (context, i) {
                        final replyDoc = replies[i];
                        final replyData = replyDoc.data() as Map<String, dynamic>;
                        return _ReplyItem(
                          reviewId: widget.reviewId,
                          replyId: replyDoc.id,
                          data: replyData,
                          purple: widget.purple,
                          orange: widget.orange,
                          recipeService: widget.recipeService,
                          onReply: () => _replyToUser(replyData['userName'] ?? "User"),
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: double.infinity,
      height: 180.sh,
      color: Colors.black12,
      child: Icon(Icons.broken_image_outlined, color: widget.purple.withValues(alpha:0.2), size: 24.sp),
    );
  }

  String _formatDate(DateTime dt) {
    return "${dt.day}/${dt.month}/${dt.year}";
  }
}

class _ReplyItem extends StatelessWidget {
  final String reviewId;
  final String replyId;
  final Map<String, dynamic> data;
  final Color purple;
  final Color orange;
  final RecipeService recipeService;
  final VoidCallback? onReply;

  const _ReplyItem({
    required this.reviewId,
    required this.replyId,
    required this.data,
    required this.purple,
    required this.orange,
    required this.recipeService,
    this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userName = data['userName'] ?? "User";
    final userImageUrl = data['userImageUrl'] as String?;
    final comment = data['comment'] ?? "";
    final createdAt = data['createdAt'] as Timestamp?;
    final dateStr = createdAt != null ? _formatDate(createdAt.toDate()) : "";
    
    final isDeleted = data['isDeleted'] == true;
    final isOwner = user != null && data['userId'] == user.uid;
    final likes = (data['likes'] as num?)?.toInt() ?? 0;
    final likedBy = List<String>.from(data['likedBy'] ?? []);
    final isLiked = user != null && likedBy.contains(user.uid);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Visual Thread Line
          Padding(
            padding: EdgeInsets.only(left: 6.sw, right: 14.sw, top: 4.sh, bottom: 4.sh),
            child: Container(
              width: 1.5.sw,
              decoration: BoxDecoration(
                color: purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 12.sh),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 12.sw,
                    backgroundColor: purple.withValues(alpha:0.1),
                    backgroundImage: (!isDeleted && userImageUrl != null && userImageUrl.trim().isNotEmpty && userImageUrl.startsWith("http"))
                        ? NetworkImage(userImageUrl)
                        : null,
                    onBackgroundImageError: (!isDeleted && userImageUrl != null && userImageUrl.trim().isNotEmpty && userImageUrl.startsWith("http")) ? (_, __) {} : null,
                    child: Icon(isDeleted ? Icons.delete_outline : Icons.person_rounded, color: purple, size: 12.sp),
                  ),
                  SizedBox(width: 10.sw),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                isDeleted ? "[Deleted]" : userName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDeleted ? purple.withValues(alpha:0.4) : purple, 
                                  fontWeight: FontWeight.bold, 
                                  fontSize: 13.sp, 
                                  fontFamily: "Satoshi"
                                ),
                              ),
                            ),
                            if (!isDeleted) ...[
                              SizedBox(width: 8.sw),
                              Text(
                                dateStr,
                                style: TextStyle(color: purple.withValues(alpha:0.5), fontSize: 10.sp, fontFamily: "Satoshi"),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: 4.sh),
                        isDeleted 
                          ? Text(
                              comment,
                              style: TextStyle(
                                color: purple.withValues(alpha:0.4),
                                fontStyle: FontStyle.italic,
                                fontSize: 13.sp,
                                fontFamily: "Satoshi",
                              ),
                            )
                          : _buildCommentWithMentions(comment, purple, orange, 13.sp),
                        if (!isDeleted) ...[
                          SizedBox(height: 6.sh),
                          Row(
                            children: [
                              _AnimatedLikeButton(
                                isLiked: isLiked,
                                likes: likes,
                                purple: purple,
                                orange: orange,
                                size: 14.sp,
                                onTap: user == null ? null : () => recipeService.toggleReplyLike(reviewId, replyId, user.uid),
                              ),
                              SizedBox(width: 24.sw),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: onReply,
                                child: Row(
                                  children: [
                                    Icon(Icons.chat_bubble_outline, size: 14.sp, color: purple.withValues(alpha:0.6)),
                                    SizedBox(width: 4.sw),
                                    Text(
                                      "Reply",
                                      style: TextStyle(
                                        color: purple.withValues(alpha:0.6),
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: "Satoshi",
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isOwner) ...[
                                const Spacer(),
                                GestureDetector(
                                  onTap: () => _confirmDeleteReply(context),
                                  child: Icon(Icons.delete_outline, size: 16.sp, color: Colors.red.withValues(alpha: 0.5)),
                                ),
                              ] else if (FirebaseAuth.instance.currentUser != null) ...[
                                const Spacer(),
                                GestureDetector(
                                  onTap: () => _reportReply(context),
                                  child: Icon(Icons.report_gmailerrorred_rounded, size: 16.sp, color: Colors.redAccent.withValues(alpha: 0.5)),
                                ),
                              ],
                            ],
                          ),
                        ],
                        SizedBox(height: 4.sh),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _reportReply(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Toaster.show(context, "Please login to report content.", isError: true);
      return;
    }

    try {
      await ModerationService().reportContent(
        contentType: 'reply',
        contentId: replyId,
        authorId: data['userId'] ?? '',
        reason: 'Inappropriate Content',
        metadata: {'parentReviewId': reviewId}, // Essential for deletion later
      );
      if (context.mounted) {
        Toaster.show(context, "Reply reported. Thank you for keeping the community safe.");
      }
    } catch (e) {
      if (context.mounted) {
        Toaster.show(context, "Error reporting reply: $e", isError: true);
      }
    }
  }

  void _confirmDeleteReply(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Reply"),
        content: const Text("Are you sure you want to delete this reply? This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              recipeService.deleteReply(reviewId, replyId);
              Navigator.pop(ctx);
              Toaster.show(context, "Reply deleted");
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return "${dt.day}/${dt.month}/${dt.year}";
  }
}

Widget _buildCommentWithMentions(String text, Color purple, Color orange, double fontSize) {
  final RegExp mentionRegex = RegExp(r"(@[^\s:]+)");
  final List<TextSpan> spans = [];

  text.splitMapJoin(
    mentionRegex,
    onMatch: (m) {
      spans.add(TextSpan(
        text: m.group(0),
        style: TextStyle(color: orange, fontWeight: FontWeight.bold, fontFamily: "Satoshi", fontSize: fontSize),
      ));
      return "";
    },
    onNonMatch: (s) {
      spans.add(TextSpan(text: s, style: TextStyle(fontSize: fontSize)));
      return "";
    },
  );

  return RichText(
    text: TextSpan(
      style: TextStyle(color: purple, height: 1.4, fontFamily: "Satoshi"),
      children: spans,
    ),
  );
}

class _AnimatedLikeButton extends StatefulWidget {
  final bool isLiked;
  final int likes;
  final Color purple;
  final Color orange;
  final double? size;
  final VoidCallback? onTap;

  const _AnimatedLikeButton({
    required this.isLiked,
    required this.likes,
    required this.purple,
    required this.orange,
    this.size,
    this.onTap,
  });

  @override
  State<_AnimatedLikeButton> createState() => _AnimatedLikeButtonState();
}

class _AnimatedLikeButtonState extends State<_AnimatedLikeButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _rotation;
  late Animation<Offset> _translation;

  @override
  void initState() {
    super.initState();
    // YouTube style: slightly longer duration to allow the hop and settle
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    
    // Scale up then elastic recoil
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4).chain(CurveTween(curve: Curves.easeOutCubic)), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 70),
    ]).animate(_controller);

    // Jump up (-Y) and slightly right (+X), then bounce back
    _translation = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween(begin: const Offset(0, 0), end: const Offset(6, -12)).chain(CurveTween(curve: Curves.easeOutCubic)), 
        weight: 30
      ),
      TweenSequenceItem(
        tween: Tween(begin: const Offset(6, -12), end: const Offset(0, 0)).chain(CurveTween(curve: Curves.elasticOut)), 
        weight: 70
      ),
    ]).animate(_controller);

    // Tilt (rotate) backwards to emphasize the thumb, then spring back
    _rotation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.4).chain(CurveTween(curve: Curves.easeOutCubic)), weight: 30),
      TweenSequenceItem(tween: Tween(begin: -0.4, end: 0.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 70),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(_AnimatedLikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLiked && !oldWidget.isLiked) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iconSize = widget.size ?? 18.sp;
    final fontSize = (widget.size != null) ? 10.sp : 12.sp;

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.translate(
                offset: _translation.value,
                child: Transform.rotate(
                  angle: _rotation.value,
                  child: Transform.scale(
                    scale: _scale.value,
                    child: child,
                  ),
                ),
              );
            },
            child: Icon(
              widget.isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
              size: iconSize,
              color: widget.isLiked ? widget.orange : widget.purple.withValues(alpha: 0.6),
            ),
          ),
          SizedBox(width: 6.sw),
          Text(
            widget.likes > 0 ? widget.likes.toString() : "Like",
            style: TextStyle(
              color: widget.isLiked ? widget.orange : widget.purple.withValues(alpha: 0.6),
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              fontFamily: "Satoshi",
            ),
          ),
        ],
      ),
    );
  }
}

class _FullScreenGallery extends StatelessWidget {
  final String imageUrl;
  final String heroTag;

  const _FullScreenGallery({required this.imageUrl, required this.heroTag});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: Hero(
              tag: heroTag,
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
                        const SizedBox(height: 16),
                        const Text("Failed to load image", style: TextStyle(color: Colors.white54)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.all(16.sw),
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaggeredItem extends StatefulWidget {
  final Widget child;
  final int index;

  const _StaggeredItem({required this.child, required this.index});

  @override
  State<_StaggeredItem> createState() => _StaggeredItemState();
}

class _StaggeredItemState extends State<_StaggeredItem> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    final delay = 50 + (widget.index * 100);
    Future.delayed(Duration(milliseconds: delay > 500 ? 500 : delay), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 600),
      opacity: _visible ? 1.0 : 0.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _visible ? 0 : 30.sh, 0),
        child: widget.child,
      ),
    );
  }
}
