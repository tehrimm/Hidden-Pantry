import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';

class NutritionistPostsScreen extends StatefulWidget {
  const NutritionistPostsScreen({super.key});

  @override
  State<NutritionistPostsScreen> createState() => _NutritionistPostsScreenState();
}

class _NutritionistPostsScreenState extends State<NutritionistPostsScreen> {
  final Color purple = const Color(0xFF462F4D);
  final Color orange = const Color(0xFFEF8A54);
  final Color bg = const Color(0xFFFFF3EB);
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text("Please log in"));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
          child: Text(
            "My Posts",
            style: TextStyle(
              color: purple,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              fontFamily: "Satoshi",
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Text(
            "Your published tips & content",
            style: TextStyle(color: purple.withValues(alpha:0.5), fontSize: 13),
          ),
        ),
        const SizedBox(height: 16),
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
                padding: const EdgeInsets.symmetric(horizontal: 22),
                itemCount: docs.length + 1,
                itemBuilder: (context, index) {
                  if (index == docs.length) return const SizedBox(height: 100);
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
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBg,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.article_outlined, size: 48, color: orange.withValues(alpha:0.5)),
          ),
          const SizedBox(height: 20),
          Text(
            "No posts yet",
            style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 18, fontFamily: "Satoshi"),
          ),
          const SizedBox(height: 8),
          Text(
            "Tap the + button to post your first tip!",
            style: TextStyle(color: purple.withValues(alpha:0.5), fontSize: 14),
          ),
        ],
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
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: purple.withValues(alpha:0.05), blurRadius: 15, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Author Row ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: cardInner,
                  backgroundImage: _photoUrl != null && _photoUrl!.startsWith("http")
                      ? NetworkImage(_photoUrl!)
                      : null,
                  child: _photoUrl == null
                      ? Icon(Icons.person, color: orange, size: 18)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _fullName ?? "You",
                        style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: "Satoshi"),
                      ),
                      Text(
                        timeAgo,
                        style: TextStyle(color: purple.withValues(alpha:0.4), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                // Tier badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: tierColors[minTier].withValues(alpha:0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(tierIcons[minTier], size: 12, color: tierColors[minTier]),
                      const SizedBox(width: 4),
                      Text(
                        tierLabels[minTier],
                        style: TextStyle(
                          color: tierColors[minTier],
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (content.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      content,
                      style: TextStyle(
                        color: purple.withValues(alpha:0.85),
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),
                  ),
                
                // Image Attachment
                if (data["imageUrl"] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        data["imageUrl"],
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: 200,
                            color: purple.withValues(alpha:0.05),
                            child: const Center(child: CircularProgressIndicator()),
                          );
                        },
                      ),
                    ),
                  ),

                // Meal Plan Attachment
                if (data["mealPlanId"] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _mealPlanPreview(data["mealPlanId"], content, uid),
                  ),

                // Document Attachment
                if (data["docUrl"] != null)
                  GestureDetector(
                    onTap: () async {
                      final url = Uri.parse(data["docUrl"]);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: purple.withValues(alpha:0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: purple.withValues(alpha:0.1)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.insert_drive_file_rounded, color: orange, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "View Attached Document",
                              style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          Icon(Icons.open_in_new_rounded, color: purple.withValues(alpha:0.4), size: 18),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Divider ──
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: purple.withValues(alpha:0.06),
          ),

          // ── Action Row: Like · Comment · Share · Delete ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                    final shareText = type == "meal_plan" 
                      ? "Check out this Meal Plan from ${_fullName ?? "a Nutritionist"}: $content"
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
    if (planId == null) return Text(fallback);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("nutritionists")
          .doc(uid)
          .collection("meal_plans")
          .doc(planId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) {
           return Text(fallback, style: TextStyle(color: purple.withValues(alpha:0.5)));
        }
        final plan = snap.data!.data() as Map<String, dynamic>;
        final title = plan["title"] ?? "Meal Plan";
        
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardInner,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: orange.withValues(alpha:0.1)),
          ),
          child: Row(
            children: [
              Container(
                 padding: const EdgeInsets.all(8),
                 decoration: BoxDecoration(color: orange.withValues(alpha:0.1), shape: BoxShape.circle),
                 child: Icon(Icons.restaurant_menu_rounded, color: orange, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 14)),
                    Text("${plan['duration'] ?? 0} Days", style: TextStyle(color: purple.withValues(alpha:0.4), fontSize: 11)),
                  ],
                ),
              ),
              const Icon(Icons.visibility_outlined, color: Colors.grey, size: 18),
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
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 5),
                Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showComments(String tipId, String uid) {
    final commentCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text("Comments", style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 18, fontFamily: "Satoshi")),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("nutritionists")
                    .doc(uid)
                    .collection("tips")
                    .doc(tipId)
                    .collection("comments")
                    .orderBy("timestamp", descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Text("No comments yet", style: TextStyle(color: purple.withValues(alpha:0.4))),
                    );
                  }
                  final docs = snapshot.data!.docs;
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final c = docs[index].data() as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: cardBg,
                              child: Icon(Icons.person, size: 14, color: orange),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c["userName"] ?? "User", style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(height: 2),
                                  Text(c["text"] ?? "", style: TextStyle(color: purple.withValues(alpha:0.7), fontSize: 13)),
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
            // Input row
            Container(
              padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: purple.withValues(alpha:0.05), blurRadius: 10, offset: const Offset(0, -4))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: commentCtrl,
                      decoration: InputDecoration(
                        hintText: "Add a comment...",
                        hintStyle: TextStyle(color: purple.withValues(alpha:0.4)),
                        filled: true,
                        fillColor: cardInner,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: orange,
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                      onPressed: () async {
                        final text = commentCtrl.text.trim();
                        if (text.isEmpty) return;
                        commentCtrl.clear();
                        final user = FirebaseAuth.instance.currentUser;
                        final tipRef = FirebaseFirestore.instance
                            .collection("nutritionists").doc(uid)
                            .collection("tips").doc(tipId);
                        
                        await tipRef.collection("comments").add({
                          "text": text,
                          "userId": user?.uid,
                          "userName": user?.displayName ?? _fullName ?? "You",
                          "timestamp": FieldValue.serverTimestamp(),
                        });
                        // Update comment count
                        await tipRef.update({"commentCount": FieldValue.increment(1)});
                      },
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

  void _confirmDelete(String docId, String uid) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFF3EB),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Delete Post?", style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontFamily: "Satoshi")),
        content: Text(
          "This action cannot be undone.",
          style: TextStyle(color: purple.withValues(alpha:0.7), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: purple.withValues(alpha:0.6), fontWeight: FontWeight.w600)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
}
