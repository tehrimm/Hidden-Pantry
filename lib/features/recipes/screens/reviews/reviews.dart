import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_service.dart';
import 'post_review.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';

class ReviewsScreen extends StatelessWidget {
  final Recipe recipe;

  const ReviewsScreen({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    final RecipeService recipeService = RecipeService();
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
            left: 30,
            top: 51,
            child: BackButtonWidget(color: purple),
          ),
          
          Positioned(
            left: 90,
            top: 51,
            right: 30,
            height: 50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Tips & Photos",
                  style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 18, fontFamily: "Satoshi"),
                ),
                Text(
                  recipe.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: purple.withValues(alpha:0.5), fontSize: 12, fontFamily: "Satoshi"),
                ),
              ],
            ),
          ),

          Positioned.fill(
            top: 110,
            child: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: recipeService.getReviews(recipe.id),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Center(child: Text("Error: ${snapshot.error}"));
                        }
                        final docs = snapshot.data?.docs ?? [];
                        
                        if (docs.isEmpty) {
                          return ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 40),
                                child: _buildEmptyState(context, orange, purple),
                              ),
                            ],
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data = doc.data() as Map<String, dynamic>;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _ReviewCard(
                                reviewId: doc.id,
                                data: data,
                                purple: purple,
                                orange: orange,
                                recipeService: recipeService,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  
                  // Sticky Add Review Bar
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: bg,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha:0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: _buildAddReviewPrompt(context, recipe, purple, orange),
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

    return FutureBuilder<List<DocumentSnapshot>>(
      future: Future.wait([
        FirebaseFirestore.instance.collection('reviews').doc(reviewId).get(),
        FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(height: 50, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
          }
          return const SizedBox.shrink();
        }

        final reviewSnapshot = snapshot.data![0];
        final userSnapshot = snapshot.data![1];
        
        final hasReviewed = reviewSnapshot.exists;
        final userData = userSnapshot.data() as Map<String, dynamic>? ?? {};
        final userName = userData['fullName'] ?? user.displayName ?? "You";
        final userImageUrl = userData['photoUrl'] ?? user.photoURL ?? "";

        return GestureDetector(
          onTap: hasReviewed 
            ? null 
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PostReviewScreen(recipe: recipe)),
                );
              },
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: purple.withValues(alpha:0.1),
                backgroundImage: (userImageUrl.trim().isNotEmpty && userImageUrl.startsWith("http")) ? NetworkImage(userImageUrl) : null,
                child: (userImageUrl.trim().isEmpty || !userImageUrl.startsWith("http")) ? Icon(Icons.person, color: purple, size: 18) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
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
                      fontSize: 12, 
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
  }

  Widget _buildEmptyState(BuildContext context, Color orange, Color purple) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mode_comment_outlined, size: 64, color: purple.withValues(alpha:0.3)),
          const SizedBox(height: 16),
          Text(
            "No reviews yet.",
            style: TextStyle(color: purple, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: "Satoshi"),
          ),
          const SizedBox(height: 8),
          Text(
            "Be the first to share your thoughts!",
            style: TextStyle(color: purple.withValues(alpha:0.6), fontFamily: "Satoshi"),
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

  const _ReviewCard({
    required this.reviewId,
    required this.data,
    required this.purple,
    required this.orange,
    required this.recipeService,
  });

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  bool _showReplyInput = false;
  bool _showReplies = true;
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
    } finally {
    }
  }

  void _replyToUser(String name) {
    setState(() {
      _showReplyInput = true;
      _showReplies = true; // Make sure they can see where it's going
      if (!_replyController.text.contains("@$name")) {
        _replyController.text = "@$name ${_replyController.text}".trim() + " ";
      }
    });
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF9E3D5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Delete Review",
          style: TextStyle(color: widget.purple, fontWeight: FontWeight.bold, fontFamily: "Satoshi"),
        ),
        content: Text(
          "Are you sure you want to delete your review? This will also revert your rating for this recipe.",
          style: TextStyle(color: widget.purple.withValues(alpha:0.8), fontFamily: "Satoshi"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancel", style: TextStyle(color: widget.purple, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
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
    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Fetch user profile
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? {};
    
    await widget.recipeService.addReply(widget.reviewId, {
      'userId': user.uid,
      'userName': userData['fullName'] ?? user.displayName ?? "User",
      'userImageUrl': userData['photoUrl'] ?? user.photoURL ?? "",
      'comment': text,
    });

    _replyController.clear();
    setState(() => _showReplyInput = false);
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9E3D5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: User Info + Date
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: widget.purple.withValues(alpha:0.1),
                backgroundImage: (userImageUrl != null && userImageUrl.toString().trim().isNotEmpty && userImageUrl.toString().startsWith("http"))
                    ? NetworkImage(userImageUrl.toString())
                    : null,
                child: (userImageUrl == null || userImageUrl.toString().trim().isEmpty || !userImageUrl.toString().startsWith("http"))
                    ? Icon(Icons.person, color: widget.purple, size: 18)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: widget.purple, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: "Satoshi"),
                    ),
                    Text(
                      dateStr,
                      style: TextStyle(color: widget.purple.withValues(alpha:0.5), fontSize: 11, fontFamily: "Satoshi"),
                    ),
                  ],
                ),
              ),
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < rating.floor() ? Icons.star : (i < rating ? Icons.star_half : Icons.star_border),
                    color: widget.orange,
                    size: 14,
                  );
                }),
              ),
            ],
          ),
              
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildCommentWithMentions(comment, widget.purple, widget.orange, 14),
          ],
          
          if (imageUrl != null && imageUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.network(
                imageUrl,
                width: double.infinity,
                height: 180,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(),
              ),
            ),
          ],
          
          // Only add this gap if we had content above to push away from the action row
          if (comment.isNotEmpty || (imageUrl != null && imageUrl.isNotEmpty))
            const SizedBox(height: 12)
          else
            const SizedBox(height: 4), // Much smaller gap if minimal review
          
          // Actions: Like, Reply & Delete
          Row(
            children: [
              GestureDetector(
                onTap: user == null ? null : () => widget.recipeService.toggleLike(widget.reviewId, user.uid),
                child: Row(
                  children: [
                    Icon(
                      isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                      size: 18,
                      color: isLiked ? widget.orange : widget.purple.withValues(alpha:0.6),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      likes > 0 ? likes.toString() : "Like",
                      style: TextStyle(
                        color: isLiked ? widget.orange : widget.purple.withValues(alpha:0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: "Satoshi",
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              GestureDetector(
                onTap: () => setState(() => _showReplyInput = !_showReplyInput),
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 18, color: widget.purple.withValues(alpha:0.6)),
                    const SizedBox(width: 6),
                    Text(
                      "Reply",
                      style: TextStyle(
                        color: widget.purple.withValues(alpha:0.6),
                        fontSize: 12,
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
                      Icon(Icons.delete_outline, color: widget.purple.withValues(alpha:0.6), size: 18),
                      const SizedBox(width: 6),
                      Text(
                        "Delete",
                        style: TextStyle(
                          color: widget.purple.withValues(alpha:0.6),
                          fontSize: 12,
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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: "Write a reply...",
                      hintStyle: TextStyle(fontSize: 12, color: widget.purple.withValues(alpha:0.4)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: widget.purple.withValues(alpha:0.1))),
                    ),
                    style: const TextStyle(fontSize: 13, fontFamily: "Satoshi"),
                  ),
                ),
                IconButton(
                  onPressed: _submitReply,
                  icon: Icon(Icons.send, color: widget.orange, size: 20),
                ),
              ],
            ),
          ],
          
          // Replies List section
          StreamBuilder<QuerySnapshot>(
            stream: widget.recipeService.getReplies(widget.reviewId),
            builder: (context, snapshot) {
              final replies = snapshot.data?.docs ?? [];
              if (replies.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => setState(() => _showReplies = !_showReplies),
                    child: Text(
                      _showReplies ? "Hide replies" : "View ${replies.length} replies",
                      style: TextStyle(color: widget.orange, fontWeight: FontWeight.bold, fontSize: 12, fontFamily: "Satoshi"),
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
      height: 180,
      color: Colors.black12,
      child: Icon(Icons.broken_image_outlined, color: widget.purple.withValues(alpha:0.2)),
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
    
    final likes = (data['likes'] as num?)?.toInt() ?? 0;
    final likedBy = List<String>.from(data['likedBy'] ?? []);
    final isLiked = user != null && likedBy.contains(user.uid);

    return Padding(
      padding: const EdgeInsets.only(top: 12, left: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: purple.withValues(alpha:0.1),
            backgroundImage: (userImageUrl != null && userImageUrl.trim().isNotEmpty && userImageUrl.startsWith("http"))
                ? NetworkImage(userImageUrl)
                : null,
            child: (userImageUrl == null || userImageUrl.trim().isEmpty || !userImageUrl.startsWith("http"))
                ? Icon(Icons.person, color: purple, size: 12)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: "Satoshi"),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      dateStr,
                      style: TextStyle(color: purple.withValues(alpha:0.5), fontSize: 10, fontFamily: "Satoshi"),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _buildCommentWithMentions(comment, purple, orange, 13),
                const SizedBox(height: 6),
                Row(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: user == null ? null : () => recipeService.toggleReplyLike(reviewId, replyId, user.uid),
                      child: Row(
                        children: [
                          Icon(
                            isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                            size: 14,
                            color: isLiked ? orange : purple.withValues(alpha:0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            likes > 0 ? likes.toString() : "Like",
                            style: TextStyle(
                              color: isLiked ? orange : purple.withValues(alpha:0.6),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              fontFamily: "Satoshi",
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onReply,
                      child: Row(
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 14, color: purple.withValues(alpha:0.6)),
                          const SizedBox(width: 4),
                          Text(
                            "Reply",
                            style: TextStyle(
                              color: purple.withValues(alpha:0.6),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              fontFamily: "Satoshi",
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
        style: TextStyle(color: orange, fontWeight: FontWeight.bold, fontFamily: "Satoshi"),
      ));
      return "";
    },
    onNonMatch: (s) {
      spans.add(TextSpan(text: s));
      return "";
    },
  );

  return RichText(
    text: TextSpan(
      style: TextStyle(color: purple, fontSize: fontSize, height: 1.4, fontFamily: "Satoshi"),
      children: spans,
    ),
  );
}
