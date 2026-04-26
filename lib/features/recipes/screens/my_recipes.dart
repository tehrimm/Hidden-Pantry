import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hidden_pantry_app/core/utils/glass_dialog.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_service.dart';

import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'recipe_details.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';
import 'package:hidden_pantry_app/features/recipes/widgets/recipe_card.dart';
import 'package:hidden_pantry_app/features/recipes/upload/upload_recipe_step1.dart';
import 'package:hidden_pantry_app/core/services/view_mode_service.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';


class MyRecipesScreen extends StatefulWidget {
  final FirebaseAuth? auth;
  final RecipeService? recipeService;
  const MyRecipesScreen({super.key, this.auth, this.recipeService});

  @override
  State<MyRecipesScreen> createState() => _MyRecipesScreenState();
}

class _MyRecipesScreenState extends State<MyRecipesScreen> {
  final Color bg = const Color(0xFFFFF3EB);
  final Color purple = const Color(0xFF462F4D);
  final Color cardColor = const Color(0xFFF9E3D5);
  final Color orange = const Color(0xFFEF8A54);

  late final RecipeService _recipeService;
  late final FirebaseAuth _auth;
  bool _isNutritionist = false;
  
  String? _name;
  String? _bio;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _auth = widget.auth ?? FirebaseAuth.instance;
    _recipeService = widget.recipeService ?? RecipeService();
    _loadProfile();
    _checkRole();
  }

  Future<void> _loadProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Try regular users first
      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (!doc.exists) {
        // Try nutritionists
        doc = await FirebaseFirestore.instance
            .collection('nutritionists')
            .doc(user.uid)
            .get();
      }
      
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _name = data['fullName'] ?? user.displayName ?? "Hidden Pantry";
          _bio = data['bio'] ?? (doc.reference.parent.id == 'nutritionists' ? "Dedicated nutritionist." : "Passionate about cooking.");
          _photoUrl = data['photoUrl'] ?? user.photoURL;
        });
      } else if (mounted) {
        setState(() {
          _name = user.displayName ?? "Hidden Pantry";
          _photoUrl = user.photoURL;
        });
      }
    } catch (e) {
      if (mounted) {}
    }
  }

  Future<void> _checkRole() async {
    final isNutr = await ViewModeService().isNutritionist();
    if (mounted) setState(() => _isNutritionist = isNutr);
  }

  void _showEditShareSheet(Recipe recipe) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _modernActionSheet(
        title: "Recipe Options",
        subtitle: recipe.name,
        actions: [
          _actionItem(
            icon: Icons.edit_rounded,
            label: "Edit Recipe",
            color: orange,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => UploadRecipeStep1(editingRecipe: recipe)),
              );
            },
          ),
          _actionItem(
            icon: Icons.share_rounded,
            label: "Share Recipe",
            color: const Color(0xFF7B61FF),
            onTap: () {
              Navigator.pop(context);
              _showShareOptions(recipe);
            },
          ),
          _actionItem(
            icon: recipe.isPublic ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            label: recipe.isPublic ? "Make Private" : "Make Public",
            color: purple,
            onTap: () {
              Navigator.pop(context);
              _toggleVisibility(recipe);
            },
          ),
          _actionItem(
            icon: Icons.delete_outline_rounded,
            label: "Delete Recipe",
            color: Colors.red,
            onTap: () {
              Navigator.pop(context);
              _confirmDelete(recipe);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(Recipe recipe) async {
    final confirmed = await GlassDialog.show<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bg,
        title: Text('Delete Recipe', style: TextStyle(color: purple, fontFamily: 'Satoshi', fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "${recipe.name}"?', style: TextStyle(color: purple, fontFamily: 'Satoshi')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: purple, fontFamily: 'Satoshi')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontFamily: 'Satoshi', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Show loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleting "${recipe.name}"...', style: const TextStyle(fontFamily: 'Satoshi'))),
        );
        
        await _recipeService.deleteRecipe(recipe.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          Toaster.show(context, 'Recipe deleted successfully');
        }
      } catch (e) {
        if (mounted) {
          Toaster.show(context, 'Error: $e', isError: true);
        }
      }
    }
  }

  Future<void> _toggleVisibility(Recipe recipe) async {
    try {
      final newStatus = !recipe.isPublic;
      await FirebaseFirestore.instance
          .collection('recipes')
          .doc(recipe.id)
          .update({'isPublic': newStatus});
      
      if (mounted) {
        Toaster.show(context, newStatus ? 'Recipe is now public' : 'Recipe is now private');
      }
    } catch (e) {
      if (mounted) {
        Toaster.show(context, 'Error updating visibility: $e', isError: true);
      }
    }
  }

  void _showManagementOptions(Recipe recipe) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _modernActionSheet(
        title: "Manage Recipe",
        subtitle: recipe.name,
        actions: [
          _actionItem(
            icon: Icons.edit_rounded,
            label: "Edit Recipe",
            color: orange,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => UploadRecipeStep1(editingRecipe: recipe)),
              );
            },
          ),
          _actionItem(
            icon: Icons.delete_outline_rounded,
            label: "Delete Recipe",
            color: Colors.red,
            onTap: () {
              Navigator.pop(context);
              _confirmDelete(recipe);
            },
          ),
        ],
      ),
    );
  }

  void _showShareOptions(Recipe recipe) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _modernActionSheet(
        title: "Share Recipe",
        subtitle: "Select how to share",
        actions: [
          _actionItem(
            icon: Icons.chat_bubble_outline_rounded,
            label: "Share with Clients",
            color: orange,
            onTap: () {
              Navigator.pop(context);
              _showSelectClientSheet(recipe);
            },
          ),
          _actionItem(
            icon: Icons.dynamic_feed_rounded,
            label: "Post to Wall",
            color: const Color(0xFF7B61FF),
            onTap: () {
              Navigator.pop(context);
              _shareToWall(recipe);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    final user = _auth.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text("Please login")));
    final double topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: bg,
      body: ClipRRect(
        borderRadius: BorderRadius.circular(30.sw),
        child: Container(
          color: bg,
          child: Stack(
            children: [
              const PatternBackground(),

              // Decorative corner shapes
              Positioned(
                top: -30.sh, right: -30.sw,
                child: Container(width: 120.sw, height: 120.sw,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: orange.withValues(alpha: 0.06))),
              ),
              Positioned(
                bottom: -40.sh, left: -40.sw,
                child: Container(width: 160.sw, height: 160.sw,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: purple.withValues(alpha: 0.04))),
              ),
              Positioned(
                top: 200.sh, left: 16.sw,
                child: Container(width: 10.sw, height: 10.sw,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: orange.withValues(alpha: 0.15))),
              ),
              Positioned(
                top: 320.sh, right: 20.sw,
                child: Transform.rotate(angle: math.pi / 4,
                  child: Container(width: 16.sw, height: 16.sw,
                    decoration: BoxDecoration(color: purple.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(3.sw)))),
              ),

              // Header
              Positioned(
                left: 30.sw, top: topPad + 36.sh,
                child: BackButtonWidget(color: purple),
              ),
              Positioned(
                left: 0, right: 0, top: topPad + 36.sh, height: 50.sh,
                child: Center(
                  child: Text('My Recipes',
                    style: TextStyle(color: purple, fontSize: 24.sp, fontWeight: FontWeight.bold, fontFamily: 'Satoshi')),
                ),
              ),

              SafeArea(
                child: Column(
                  children: [
                    SizedBox(height: 96.sh),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(horizontal: 30.sw),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 20.sh),
                            _FadeSlideEntry(delayMs: 100, child: Center(child: _buildProfileSection())),
                            SizedBox(height: 30.sh),
                            _FadeSlideEntry(delayMs: 250, child: _buildRecipeList(user.uid)),
                            SizedBox(height: 30.sh),
                          ],
                        ),
                      ),
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


  void _showSelectClientSheet(Recipe recipe) {
    final user = _auth.currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32.sw)),
          boxShadow: [
            BoxShadow(color: purple.withValues(alpha: 0.1), blurRadius: 40, offset: const Offset(0, -10)),
          ],
        ),
        child: Column(
          children: [
            SizedBox(height: 12.sh),
            Container(
              width: 40.sw, height: 4.sh,
              decoration: BoxDecoration(color: purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(2.sw)),
            ),
            SizedBox(height: 24.sh),
            Text("Share with Client", style: TextStyle(color: purple, fontSize: 20.sp, fontWeight: FontWeight.w900, fontFamily: "Satoshi")),
            SizedBox(height: 4.sh),
            Text("Select a client from your subscriptions", style: TextStyle(color: purple.withValues(alpha: 0.4), fontSize: 13.sp, fontWeight: FontWeight.w500)),
            SizedBox(height: 24.sh),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchClientsForShare(user.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: orange, strokeWidth: 2.sw));
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text("Error loading clients", style: TextStyle(color: purple.withValues(alpha: 0.5))));
                  }

                  final clients = snapshot.data ?? [];
                  if (clients.isEmpty) return Center(child: Text("No clients found with matching benefits.", style: TextStyle(color: purple.withValues(alpha: 0.4))));

                  return ListView.separated(
                    padding: EdgeInsets.fromLTRB(24.sw, 0, 24.sw, 40.sh),
                    itemCount: clients.length,
                    separatorBuilder: (_, __) => SizedBox(height: 12.sh),
                    itemBuilder: (context, index) {
                      final client = clients[index];
                      final otherUserId = client["userId"] as String;
                      final otherUserName = client["name"] as String;
                      final otherUserPhoto = client["photoUrl"] as String?;
                      final chatId = client["chatId"] as String;

                      return _FadeSlideEntry(
                        delayMs: 50 * index,
                        child: Material(
                          color: Colors.white.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(20.sw),
                          child: InkWell(
                            onTap: () async {
                              HapticFeedback.mediumImpact();
                               try {
                                 await FirebaseFirestore.instance
                                   .collection("chats")
                                   .doc(chatId)
                                   .collection("messages")
                                   .add({
                                     "senderId": user.uid,
                                     "type": "recipe_share",
                                     "recipeId": recipe.id,
                                     "recipeName": recipe.name,
                                     "recipeImage": recipe.imageUrl,
                                     "timestamp": FieldValue.serverTimestamp(),
                                     "read": false,
                                   });
                                 
                                 await FirebaseFirestore.instance.collection("chats").doc(chatId).set({
                                   "lastMessage": "Shared a recipe: ${recipe.name}",
                                   "lastMessageTime": FieldValue.serverTimestamp(),
                                   "userUnread": FieldValue.increment(1),
                                   "nutritionistUnread": 0,
                                   "participants": FieldValue.arrayUnion([user.uid, otherUserId]),
                                 }, SetOptions(merge: true));

                                 if (context.mounted) {
                                   Navigator.pop(context);
                                   Toaster.show(context, "Recipe sent to $otherUserName");
                                 }
                               } catch (e) {
                                 if (context.mounted) {
                                   Toaster.show(context, "Error sharing recipe: $e", isError: true);
                                 }
                               }
                            },
                            borderRadius: BorderRadius.circular(20.sw),
                            child: Container(
                              padding: EdgeInsets.all(16.sw),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20.sw),
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24.sw,
                                    backgroundColor: purple.withValues(alpha:0.05),
                                    backgroundImage: otherUserPhoto != null ? NetworkImage(otherUserPhoto) : null,
                                    child: otherUserPhoto == null ? Icon(Icons.person, color: purple.withValues(alpha: 0.3), size: 24.sp) : null,
                                  ),
                                  SizedBox(width: 16.sw),
                                  Expanded(
                                    child: Text(otherUserName, style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 16.sp)),
                                  ),
                                  Container(
                                    padding: EdgeInsets.all(10.sw),
                                    decoration: BoxDecoration(
                                      color: orange.withValues(alpha:0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.send_rounded, color: orange, size: 18.sp),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchClientsForShare(String nutritionistId) async {
    final Map<String, Map<String, dynamic>> clientMap = {};
    final String requiredBenefit = "nutritionist approved recipes";

    final subsSnap = await FirebaseFirestore.instance
        .collection("subscriptions")
        .where("nutritionistId", isEqualTo: nutritionistId)
        .where("status", whereIn: ["active", "trialing"])
        .get();

    for (var doc in subsSnap.docs) {
      final data = doc.data();
      final userId = data["userId"] as String?;
      final planId = data["planId"] as String?;

      if (userId == null || userId == nutritionistId) continue;

      bool hasBenefit = false;
      if (planId != null) {
        try {
          final planDoc = await FirebaseFirestore.instance
              .collection("nutritionists")
              .doc(nutritionistId)
              .collection("subscription_plans")
              .doc(planId)
              .get();
          
          if (planDoc.exists) {
            final List? benefits = planDoc.data()?["benefits"];
            if (benefits != null) {
              hasBenefit = benefits.any((b) {
                final String title = (b is Map ? (b["title"] ?? b["text"] ?? "") : b).toString().toLowerCase();
                return title.contains(requiredBenefit);
              });
            }
          }
        } catch (_) {}
      }
      if (!hasBenefit) continue;

      final chatId = "chat_${userId}_$nutritionistId";
      clientMap[userId] = {
        "userId": userId,
        "chatId": chatId,
      };
    }

    final List<Map<String, dynamic>> clients = [];
    for (var entry in clientMap.values) {
      final userId = entry["userId"] as String;
      try {
        final userDoc = await FirebaseFirestore.instance.collection("users").doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          entry["name"] = userData["fullName"] ?? "User";
          entry["photoUrl"] = userData["photoUrl"];
        } else {
          entry["name"] = "User";
        }
      } catch (_) {
        entry["name"] = "User";
      }
      clients.add(entry);
    }
    
    clients.sort((a, b) => (a["name"] as String).compareTo(b["name"] as String));
    return clients;
  }

  Future<void> _shareToWall(Recipe recipe) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final Map<String, dynamic> postData = {
        "content": "Check out my new recipe: ${recipe.name}",
        "recipeId": recipe.id,
        "recipeName": recipe.name,
        "imageUrl": recipe.imageUrl,
        "timestamp": FieldValue.serverTimestamp(),
        "minTier": 0, // Public by default if on wall
        "likes": 0,
        "commentCount": 0,
        "likedBy": [],
        "type": "unified_post",
        "hasRecipe": true,
      };

      await FirebaseFirestore.instance
          .collection("nutritionists")
          .doc(user.uid)
          .collection("tips")
          .add(postData);

      if (mounted) {
        Toaster.show(context, "Recipe posted to your wall!");
      }
    } catch (e) {
      if (mounted) {
        Toaster.show(context, "Error posting to wall: $e", isError: true);
      }
    }
  }

  Widget _buildProfileSection() {
    return Column(
      children: [
        Container(
          width: 80.sw, height: 80.sw,
          decoration: BoxDecoration(
            color: const Color(0xFFD9D9D9),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12)],
          ),
          child: ClipOval(
            child: SizedBox(
              width: 80.sw, height: 80.sw,
              child: _photoUrl != null
                  ? Image.network(
                      _photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Icon(Icons.person_rounded, color: purple, size: 40.sw),
                      ),
                    )
                  : Center(
                      child: Icon(Icons.person_rounded, color: purple, size: 40.sw),
                    ),
            ),
          ),
        ),
        SizedBox(height: 12.sh),
        Text(_name ?? 'Hidden Pantry',
          style: TextStyle(color: purple, fontSize: 16.sp, fontWeight: FontWeight.w700, fontFamily: 'Satoshi')),
        SizedBox(height: 4.sh),
        Text(_bio ?? 'Passionate about cooking.',
          textAlign: TextAlign.center,
          style: TextStyle(color: purple.withValues(alpha: 0.5), fontSize: 13.sp, fontWeight: FontWeight.w500, fontFamily: 'Satoshi')),
      ],
    );
  }

  Widget _buildRecipeList(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('recipes')
          .where('author_id', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: orange, strokeWidth: 2.5));
        }
        
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.only(top: 40.sh),
              child: Column(
                children: [
                  Container(
                    width: 80.sw, height: 80.sw,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [orange.withValues(alpha: 0.15), orange.withValues(alpha: 0.05)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                    ),
                    child: Icon(Icons.restaurant_menu_rounded, color: orange, size: 36.sw),
                  ),
                  SizedBox(height: 20.sh),
                  Text("No recipes yet",
                    style: TextStyle(color: purple, fontSize: 17.sp, fontWeight: FontWeight.w700, fontFamily: 'Satoshi')),
                  SizedBox(height: 6.sh),
                  Text("Upload your first recipe to see it here!",
                    style: TextStyle(color: purple.withValues(alpha: 0.45), fontSize: 13.sp, fontFamily: 'Satoshi')),
                ],
              ),
            ),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 157 / 250,
            crossAxisSpacing: 15.sw,
            mainAxisSpacing: 15.sh,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final recipe = Recipe.fromJson(data);

            return RecipeCard(
              recipe: recipe,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(context, MaterialPageRoute(builder: (_) => RecipeDetailsScreen(recipe: recipe)));
              },
              onLongPress: () => (_isNutritionist ? _showEditShareSheet(recipe) : _showManagementOptions(recipe)),
              onShareTap: _isNutritionist ? () => _showShareOptions(recipe) : null,
              onVisibilityTap: _isNutritionist ? () => _toggleVisibility(recipe) : null,
              isPublic: recipe.isPublic,
              isNutritionist: _isNutritionist,
            );
          },
        );
      },
    );
  }

  Widget _modernActionSheet({
    required String title,
    required String subtitle,
    required List<Widget> actions,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24.sw, vertical: 20.sh),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32.sw)),
        boxShadow: [
          BoxShadow(color: purple.withValues(alpha: 0.1), blurRadius: 40, offset: const Offset(0, -10)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40.sw, height: 4.sh,
            decoration: BoxDecoration(color: purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(2.sw)),
          ),
          SizedBox(height: 24.sh),
          Text(title, style: TextStyle(color: purple, fontSize: 20.sp, fontWeight: FontWeight.w900, fontFamily: "Satoshi")),
          SizedBox(height: 4.sh),
          Text(subtitle, style: TextStyle(color: purple.withValues(alpha: 0.4), fontSize: 13.sp, fontWeight: FontWeight.w500, fontFamily: "Satoshi")),
          SizedBox(height: 32.sh),
          ...actions.asMap().entries.map((entry) {
            final index = entry.key;
            final action = entry.value;
            return _FadeSlideEntry(
              delayMs: 50 * index,
              child: action,
            );
          }),
          SizedBox(height: 12.sh),
        ],
      ),
    );
  }

  Widget _actionItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.sh),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(20.sw),
          child: Container(
            padding: EdgeInsets.all(16.sw),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20.sw),
              border: Border.all(color: color.withValues(alpha: 0.1), width: 1),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.sw),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12.sw),
                  ),
                  child: Icon(icon, color: color, size: 20.sw),
                ),
                SizedBox(width: 16.sw),
                Text(
                  label,
                  style: TextStyle(
                    color: color == Colors.red ? Colors.red : purple,
                    fontWeight: FontWeight.w700,
                    fontSize: 16.sp,
                    fontFamily: "Satoshi",
                  ),
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_ios_rounded, color: color.withValues(alpha: 0.3), size: 14.sw),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child));
  }
}
