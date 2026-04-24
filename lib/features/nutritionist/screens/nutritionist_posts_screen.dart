import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/core/utils/glass_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_service.dart';
import 'package:hidden_pantry_app/features/recipes/screens/recipe_details.dart';

class NutritionistPostsScreen extends StatefulWidget {
  const NutritionistPostsScreen({super.key});

  @override
  State<NutritionistPostsScreen> createState() => _NutritionistPostsScreenState();
}

class _NutritionistPostsScreenState extends State<NutritionistPostsScreen> {
  final Color purple = const Color(0xFF462F4D);
  final Color orange = const Color(0xFFEF8A54);
  final Color bg = const Color(0xFFFFF7F2);
  final Color cardBg = const Color(0xFFF9E3D5);
  final Color cardInner = const Color(0xFFFFF2EA);

  String? _fullName;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection("nutritionists").doc(uid).get();
    if (doc.exists && mounted) {
      setState(() {
        _fullName = doc.data()?["fullName"] ?? "Nutritionist";
        _photoUrl = doc.data()?["photoUrl"];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text("Please log in"));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(22.sw, 12.sh, 22.sw, 0),
          child: Text(
            "My Posts",
            style: TextStyle(
              color: purple,
              fontSize: 28.sp,
              fontWeight: FontWeight.w900,
              fontFamily: "Satoshi",
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 22.sw),
          child: Text(
            "Your published tips & content",
            style: TextStyle(color: purple.withValues(alpha:0.5), fontSize: 13.sp),
          ),
        ),
        SizedBox(height: 16.sh),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("nutritionists")
                .doc(uid)
                .collection("tips")
                .orderBy("timestamp", descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text("Error: ${snapshot.error}", style: TextStyle(color: purple.withValues(alpha:0.5))));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return _emptyState();
              }

              return ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 22.sw),
                itemCount: docs.length + 1,
                itemBuilder: (context, index) {
                  if (index == docs.length) return SizedBox(height: 100.sh);
                  final data = docs[index].data() as Map<String, dynamic>;
                  final docId = docs[index].id;
                  return _postCard(data, docId, uid);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24.sw),
            decoration: BoxDecoration(
              color: cardBg,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.article_outlined, size: 48.sw, color: orange.withValues(alpha:0.5)),
          ),
          SizedBox(height: 20.sh),
          Text(
            "No posts yet",
            style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 18.sp, fontFamily: "Satoshi"),
          ),
          SizedBox(height: 8.sh),
          Text(
            "Tap the + button to post your first tip!",
            style: TextStyle(color: purple.withValues(alpha:0.5), fontSize: 14.sp),
          ),
        ],
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Image",
      barrierColor: Colors.black.withValues(alpha: 0.9),
      pageBuilder: (context, anim1, anim2) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                top: 50.sh,
                right: 20.sw,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: EdgeInsets.all(8.sw),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded, color: Colors.white, size: 24.sw),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showComments(String tipId, String nutritionistId) {
    if (tipId.isEmpty || nutritionistId.isEmpty) return;
    final commentCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32.sw)),
        ),
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.only(top: 12.sh),
              width: 40.sw, height: 4.sh,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2.sw)),
            ),
            Padding(
              padding: EdgeInsets.all(20.sw),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Comments", style: TextStyle(color: purple, fontWeight: FontWeight.w900, fontSize: 20.sp, fontFamily: "Satoshi")),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close_rounded, color: purple.withValues(alpha: 0.4)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("nutritionists")
                    .doc(nutritionistId)
                    .collection("tips")
                    .doc(tipId)
                    .collection("comments")
                    .orderBy("timestamp", descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, color: purple.withValues(alpha: 0.1), size: 48.sw),
                          SizedBox(height: 12.sh),
                          Text("No comments yet", style: TextStyle(color: purple.withValues(alpha: 0.3), fontSize: 14.sp)),
                        ],
                      ),
                    );
                  }
                  final docs = snapshot.data!.docs;
                  return ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 20.sw),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final c = docs[index].data() as Map<String, dynamic>;
                      final Timestamp? ts = c["timestamp"] as Timestamp?;
                      final time = ts != null ? _timeAgo(ts.toDate()) : "Just now";
                      
                      return Padding(
                        padding: EdgeInsets.only(bottom: 20.sh),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 16.sw,
                              backgroundColor: cardBg,
                              backgroundImage: c["userPhotoUrl"] != null ? NetworkImage(c["userPhotoUrl"]) : null,
                              child: c["userPhotoUrl"] == null ? Icon(Icons.person, size: 16.sw, color: orange) : null,
                            ),
                            SizedBox(width: 12.sw),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(c["userName"] ?? "User", style: TextStyle(color: purple, fontWeight: FontWeight.w900, fontSize: 13.sp)),
                                      SizedBox(width: 8.sw),
                                      Text(time, style: TextStyle(color: purple.withValues(alpha: 0.3), fontSize: 10.sp)),
                                    ],
                                  ),
                                  SizedBox(height: 4.sh),
                                  Text(
                                    c["text"] ?? "", 
                                    style: TextStyle(color: purple.withValues(alpha: 0.7), fontSize: 13.sp, height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(20.sw, 12.sh, 20.sw, MediaQuery.of(context).viewInsets.bottom + 24.sh),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: purple.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, -5))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: commentCtrl,
                      style: TextStyle(fontSize: 14.sp, fontFamily: "Satoshi", fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: "Add a comment...",
                        hintStyle: TextStyle(color: purple.withValues(alpha: 0.3)),
                        filled: true,
                        fillColor: purple.withValues(alpha: 0.03),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(25.sw), borderSide: BorderSide.none),
                        contentPadding: EdgeInsets.symmetric(horizontal: 20.sw, vertical: 12.sh),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.sw),
                  GestureDetector(
                    onTap: () async {
                      final text = commentCtrl.text.trim();
                      if (text.isEmpty) return;
                      commentCtrl.clear();
                      final user = FirebaseAuth.instance.currentUser;
                      final tipRef = FirebaseFirestore.instance
                          .collection("nutritionists").doc(nutritionistId)
                          .collection("tips").doc(tipId);
                      
                      await tipRef.collection("comments").add({
                        "text": text,
                        "userId": user?.uid,
                        "userName": user?.displayName ?? "Expert",
                        "userPhotoUrl": user?.photoURL,
                        "timestamp": FieldValue.serverTimestamp(),
                      });
                      await tipRef.update({"commentCount": FieldValue.increment(1)});
                    },
                    child: Container(
                      padding: EdgeInsets.all(12.sw),
                      decoration: BoxDecoration(color: orange, shape: BoxShape.circle),
                      child: Icon(Icons.send_rounded, color: Colors.white, size: 20.sw),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _postCard(Map<String, dynamic> data, String docId, String uid) {
    final String content = data["content"] ?? "";
    final String type = data["type"] ?? "tip";
    final int minTier = data["minTier"] ?? 0;
    final Timestamp? timestamp = data["timestamp"] as Timestamp?;
    final timeAgo = timestamp != null ? _timeAgo(timestamp.toDate()) : "Just now";
    final likes = (data["likes"] ?? 0) as int;
    final comments = (data["commentCount"] ?? 0) as int;

    final List<String> tierLabels = ["FREE", "SILVER", "GOLD", "PLATINUM"];
    final List<Color> tierColors = [
      const Color(0xFFEF8A54),
      const Color(0xFF708090),
      const Color(0xFFDAA520),
      const Color(0xFF4B0082)
    ];
    final List<IconData> tierIcons = [
      Icons.public_rounded,
      Icons.star_half_rounded,
      Icons.star_rounded,
      Icons.diamond_rounded
    ];

    return Container(
      margin: EdgeInsets.only(bottom: 14.sh),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9F5),
        borderRadius: BorderRadius.circular(22.sw),
        boxShadow: [
          BoxShadow(
            color: purple.withValues(alpha: 0.03),
            blurRadius: 15.sw,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Author Row ──
          Padding(
            padding: EdgeInsets.fromLTRB(12.sw, 12.sh, 12.sw, 0),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(2.sw),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: orange.withValues(alpha: 0.2), width: 1.5),
                  ),
                  child: CircleAvatar(
                    radius: 16.sw,
                    backgroundColor: cardInner,
                    backgroundImage: _photoUrl != null && _photoUrl!.startsWith("http")
                        ? NetworkImage(_photoUrl!)
                        : null,
                    child: _photoUrl == null
                        ? Icon(Icons.person, color: orange, size: 16.sw)
                        : null,
                  ),
                ),
                SizedBox(width: 12.sw),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _fullName ?? "You",
                        style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 13.sp, fontFamily: "Satoshi"),
                      ),
                      Text(
                        timeAgo,
                        style: TextStyle(color: purple.withValues(alpha:0.3), fontSize: 10.sp),
                      ),
                    ],
                  ),
                ),
                // Tier badge
                if (minTier > 0)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.sw, vertical: 4.sh),
                    decoration: BoxDecoration(
                      color: (minTier == 3 
                          ? const Color(0xFF6A4C93) // Platinum
                          : minTier == 2 
                            ? const Color(0xFFD4AF37) // Gold
                            : const Color(0xFF8A9EA7)).withValues(alpha:0.1), // Silver
                      borderRadius: BorderRadius.circular(10.sw),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          minTier == 3 ? Icons.diamond_rounded : (minTier == 2 ? Icons.star_rounded : Icons.star_half_rounded), 
                          size: 10.sw, 
                          color: (minTier == 3 ? const Color(0xFF6A4C93) : (minTier == 2 ? const Color(0xFFD4AF37) : const Color(0xFF8A9EA7)))
                        ),
                        SizedBox(width: 4.sw),
                        Text(
                          minTier == 3 ? "PLATINUM" : minTier == 2 ? "GOLD" : "SILVER",
                          style: TextStyle(
                            color: (minTier == 3 ? const Color(0xFF6A4C93) : (minTier == 2 ? const Color(0xFFD4AF37) : const Color(0xFF8A9EA7))),
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // ── Content ──
          Padding(
            padding: EdgeInsets.fromLTRB(12.sw, 14.sh, 12.sw, 10.sh),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (content.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(bottom: 8.sh),
                    child: Text(
                      content,
                      style: TextStyle(
                        color: purple.withValues(alpha:0.75),
                        fontSize: 13.sp,
                        height: 1.4,
                      ),
                    ),
                  ),
                
                // Image Attachment
                if (data["imageUrl"] != null)
                  Padding(
                    padding: EdgeInsets.only(bottom: 12.sh),
                    child: GestureDetector(
                      onTap: () => _showFullScreenImage(context, data["imageUrl"]),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16.sw),
                        child: Image.network(
                          data["imageUrl"],
                          width: double.infinity,
                          height: 180.sh,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 180.sh,
                              color: purple.withValues(alpha: 0.05),
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: orange,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                // Meal Plan Attachment
                if (data["mealPlanId"] != null)
                  Padding(
                    padding: EdgeInsets.only(bottom: 12.sh),
                    child: _mealPlanPreview(data["mealPlanId"], content, uid),
                  ),

                // Shared Recipe Attachment
                if (data["recipeId"] != null)
                  Padding(
                    padding: EdgeInsets.only(bottom: 12.sh),
                    child: _recipePreview(data["recipeId"], data["recipeName"], data["recipeImageUrl"] ?? data["imageUrl"]),
                  ),
                if (data["docUrl"] != null)
                  Padding(
                    padding: EdgeInsets.only(bottom: 12.sh),
                    child: Text("Document: ${data["docName"] ?? "Attachment"}", style: TextStyle(color: orange, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
          // ── Divider ──
          Container(
            height: 1.sh,
            margin: EdgeInsets.symmetric(horizontal: 16.sw),
            color: purple.withValues(alpha:0.06),
          ),

          // ── Action Row: Like · Comment · Share · Delete ──
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.sw, vertical: 6.sh),
            child: Row(
              children: [
                // Like (Disabled for Nutritionists)
                Builder(
                  builder: (context) {
                    final List likedBy = data["likedBy"] as List? ?? [];
                    final String currentUserUid = FirebaseAuth.instance.currentUser?.uid ?? "";
                    final bool hasLiked = likedBy.contains(currentUserUid);

                    return _actionButton(
                      icon: hasLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      label: likes > 0 ? "$likes" : "Like",
                      color: hasLiked ? Colors.red : purple.withValues(alpha:0.5),
                      onTap: () {
                        // Nutritionists cannot like posts
                      },
                    );
                  },
                ),
                // Comment
                _actionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: comments > 0 ? "$comments" : "Comment",
                  color: purple.withValues(alpha:0.5),
                  onTap: () {
                    if (docId.isNotEmpty && uid.isNotEmpty) {
                      _showComments(docId, uid);
                    }
                  },
                ),
                // Share
                _actionButton(
                  icon: Icons.share_outlined,
                  label: "Share",
                  color: purple.withValues(alpha:0.5),
                  onTap: () {
                    final shareText = type == "meal_plan" || data["mealPlanId"] != null
                      ? "Check out this Meal Plan from ${_fullName ?? "a Nutritionist"}: $content"
                      : data["recipeId"] != null
                          ? "Check out this Recipe from ${_fullName ?? "a Nutritionist"}: ${data['recipeName'] ?? 'Shared Recipe'}\n\n$content"
                          : "💡 Health Tip from ${_fullName ?? "a Nutritionist"}:\n\n$content\n\n— Hidden Pantry";
                    Clipboard.setData(ClipboardData(text: shareText));
                    Toaster.show(context, "Copied to clipboard!");
                  },
                ),
                const Spacer(),
                // Delete
                _actionButton(
                  icon: Icons.delete_outline_rounded,
                  label: "",
                  color: Colors.red.withValues(alpha:0.4),
                  onTap: () {
                    if (docId.isNotEmpty && uid.isNotEmpty) {
                      _confirmDelete(docId, uid);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mealPlanPreview(String? planId, String fallback, String uid) {
    if (planId == null) return Container();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("nutritionists")
          .doc(uid)
          .collection("meal_plans")
          .doc(planId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) {
           return Text(fallback, style: TextStyle(color: purple, fontWeight: FontWeight.bold));
        }
        final plan = snap.data!.data() as Map<String, dynamic>;
        final title = plan["title"] ?? "Expert Meal Plan";
        final days = plan["duration"] ?? 0;
        final cals = plan["targetCalories"] ?? 0;
        
        return Container(
          padding: EdgeInsets.all(16.sw),
          decoration: BoxDecoration(
            color: cardInner,
            borderRadius: BorderRadius.circular(16.sw),
            border: Border.all(color: orange.withValues(alpha:0.1)),
          ),
          child: Row(
            children: [
              Container(
                 padding: EdgeInsets.all(10.sw),
                 decoration: BoxDecoration(color: orange.withValues(alpha:0.1), shape: BoxShape.circle),
                 child: Icon(Icons.restaurant_menu_rounded, color: orange, size: 24.sw),
              ),
              SizedBox(width: 16.sw),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 16.sp)),
                    SizedBox(height: 4.sh),
                    Text("$days Days • $cals kcal", style: TextStyle(color: purple.withValues(alpha:0.5), fontSize: 13.sp)),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.sw, vertical: 8.sh),
                decoration: BoxDecoration(
                  color: orange,
                  borderRadius: BorderRadius.circular(10.sw),
                ),
                child: Text(
                  "View",
                  style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12.sw),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.sw, vertical: 8.sh),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18.sw, color: color),
              if (label.isNotEmpty) ...[
                SizedBox(width: 5.sw),
                Text(label, style: TextStyle(color: color, fontSize: 12.sp, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
      ),
    );
  }


  void _confirmDelete(String docId, String uid) {
    GlassDialog.show(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFF3EB),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.sw)),
        title: Text("Delete Post?", style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontFamily: "Satoshi", fontSize: 18.sp)),
        content: Text(
          "This action cannot be undone.",
          style: TextStyle(color: purple.withValues(alpha:0.7), fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: purple.withValues(alpha:0.6), fontWeight: FontWeight.w600, fontSize: 14.sp)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FirebaseFirestore.instance
                    .collection("nutritionists").doc(uid)
                    .collection("tips").doc(docId).delete();
                if (mounted) {
                  Toaster.show(context, "Post deleted");
                }
              } catch (e) {
                if (mounted) {
                  Toaster.show(context, "Error: $e", isError: true);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF8A54), // orange
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.sw)),
            ),
            child: Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.sp)),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    if (diff.inDays < 7) return "${diff.inDays}d ago";
    return "${date.day}/${date.month}/${date.year}";
  }

  Widget _recipePreview(String recipeId, String? fallbackName, String? fallbackImage) {
    if (recipeId.isEmpty) return Container();
    final title = (fallbackName == null || fallbackName.isEmpty) ? "Shared Recipe" : fallbackName;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection("recipes").doc(recipeId).snapshots(),
      builder: (context, snap) {
        String name = title;
        String? img = fallbackImage;

        if (snap.hasData && snap.data!.exists) {
          final rData = snap.data!.data() as Map<String, dynamic>;
          name = rData["name"] ?? name;
          img = rData["imageUrl"] ?? rData["image_url"] ?? img;
        }

        return Container(
          padding: EdgeInsets.all(16.sw),
          decoration: BoxDecoration(
            color: cardInner,
            borderRadius: BorderRadius.circular(16.sw),
            border: Border.all(color: orange.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Container(
                width: 50.sw,
                height: 50.sh,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12.sw),
                ),
                child: (img != null && img.startsWith("http"))
                    ? Image.network(img, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _recipeCardPlaceholder())
                    : _recipeCardPlaceholder(),
              ),
              SizedBox(width: 16.sw),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: purple,
                        fontWeight: FontWeight.bold,
                        fontSize: 16.sp,
                        fontFamily: "Satoshi",
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.sh),
                    Text(
                      "Shared Recipe Instructions",
                      style: TextStyle(
                        color: purple.withValues(alpha: 0.5),
                        fontSize: 13.sp,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.sw),
              InkWell(
                onTap: () => _navigateToRecipe(recipeId),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.sw, vertical: 8.sh),
                  decoration: BoxDecoration(
                    color: orange,
                    borderRadius: BorderRadius.circular(10.sw),
                  ),
                  child: Text(
                    "View",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
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

  Widget _recipeCardPlaceholder() {
    return Container(
      decoration: BoxDecoration(color: orange.withValues(alpha: 0.1), shape: BoxShape.circle),
      child: Icon(Icons.restaurant_menu_rounded, color: orange, size: 24.sw),
    );
  }

  Future<void> _navigateToRecipe(String recipeId) async {
    try {
      final recipe = await RecipeService().getRecipeById(recipeId);
      if (recipe != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RecipeDetailsScreen(recipe: recipe),
          ),
        );
      } else if (mounted) {
        Toaster.show(context, "Recipe not found", isError: true);
      }
    } catch (e) {
      if (mounted) {
        Toaster.show(context, "Error loading recipe: $e", isError: true);
      }
    }
  }
}
