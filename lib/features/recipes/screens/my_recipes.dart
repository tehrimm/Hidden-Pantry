import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
  const MyRecipesScreen({super.key});

  @override
  State<MyRecipesScreen> createState() => _MyRecipesScreenState();
}

class _MyRecipesScreenState extends State<MyRecipesScreen> {
  final Color bg = const Color(0xFFFFF3EB);
  final Color purple = const Color(0xFF462F4D);
  final Color cardColor = const Color(0xFFF9E3D5);
  final Color orange = const Color(0xFFEF8A54);

  final RecipeService _recipeService = RecipeService();
  bool _isNutritionist = false;
  
  String? _name;
  String? _bio;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _checkRole();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
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
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFF9E3D5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30.sw)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit_rounded, color: const Color(0xFF462F4D), size: 24.sp),
              title: Text('Edit Recipe', style: TextStyle(color: const Color(0xFF462F4D), fontFamily: 'Satoshi', fontSize: 16.sp)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UploadRecipeStep1(editingRecipe: recipe),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.share_rounded, color: const Color(0xFF462F4D), size: 24.sp),
              title: Text('Share Recipe', style: TextStyle(color: const Color(0xFF462F4D), fontFamily: 'Satoshi', fontSize: 16.sp)),
              onTap: () {
                Navigator.pop(context);
                _showShareOptions(recipe);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Recipe recipe) async {
    final confirmed = await showDialog<bool>(
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(24.sw),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.sw)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50.sw, height: 5.sh,
              decoration: BoxDecoration(color: orange, borderRadius: BorderRadius.circular(3.sw)),
            ),
            SizedBox(height: 24.sh),
            Text(
              "Manage Recipe",
              style: TextStyle(color: purple, fontSize: 20.sp, fontWeight: FontWeight.w900, fontFamily: "Satoshi"),
            ),
            SizedBox(height: 24.sh),
            ListTile(
              leading: Icon(Icons.edit_rounded, color: orange, size: 24.sp),
              title: Text("Edit Recipe", style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 16.sp)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UploadRecipeStep1(editingRecipe: recipe),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: Colors.red, size: 24.sp),
              title: Text("Delete Recipe", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16.sp)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(recipe);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showShareOptions(Recipe recipe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(24.sw),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.sw)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50.sw, height: 5.sh,
              decoration: BoxDecoration(color: orange, borderRadius: BorderRadius.circular(3.sw)),
            ),
            SizedBox(height: 24.sh),
            Text(
              "Share Recipe",
              style: TextStyle(color: purple, fontSize: 20.sp, fontWeight: FontWeight.w900, fontFamily: "Satoshi"),
            ),
            SizedBox(height: 24.sh),
            ListTile(
              leading: Icon(Icons.chat_bubble_outline_rounded, color: orange, size: 24.sp),
              title: Text("Share with Clients", style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 16.sp)),
              onTap: () {
                Navigator.pop(context);
                _showSelectClientSheet(recipe);
              },
            ),
            ListTile(
              leading: Icon(Icons.dynamic_feed_rounded, color: orange, size: 24.sp),
              title: Text("Post to Wall", style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 16.sp)),
              onTap: () {
                Navigator.pop(context);
                _shareToWall(recipe);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    final user = FirebaseAuth.instance.currentUser;
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

                // Standardized Header - Back Button
                Positioned(
                  left: 30.sw,
                  top: topPad + 36.sh,
                  child: BackButtonWidget(color: purple),
                ),

                // Standardized Header - Title
                Positioned(
                  left: 0,
                  right: 0,
                  top: topPad + 36.sh,
                  height: 50.sh,
                  child: Center(
                    child: Text(
                      'My Recipes',
                      style: TextStyle(
                        color: purple,
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Satoshi',
                      ),
                    ),
                  ),
                ),



                SafeArea(
                  child: Column(
                    children: [
                      SizedBox(height: 96.sh), // Standardized gap for fixed header
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(horizontal: 30.sw),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 20.sh),
                            Center(child: _buildProfileSection()),
                            SizedBox(height: 30.sh),
                            Text(
                              "My Recipes",
                              style: TextStyle(
                                color: purple,
                                fontSize: 20.sp,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Satoshi',
                              ),
                            ),
                            SizedBox(height: 20.sh),
                            _buildRecipeList(user.uid),
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30.sw)),
        ),
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.only(top: 10.sh, bottom: 20.sh),
              width: 50.sw, height: 5.sh,
              decoration: BoxDecoration(color: orange, borderRadius: BorderRadius.circular(3.sw)),
            ),
            Text("Select Client to Share With", style: TextStyle(color: purple, fontSize: 18.sp, fontWeight: FontWeight.bold)),
            SizedBox(height: 16.sh),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchClientsForShare(user.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: orange));
                  }
                  if (snapshot.hasError) {
                    return const Center(child: Text("Error loading clients"));
                  }

                  final clients = snapshot.data ?? [];
                  if (clients.isEmpty) return const Center(child: Text("No clients found with matching benefits."));

                  return ListView.separated(
                    padding: EdgeInsets.all(20.sw),
                    itemCount: clients.length,
                    separatorBuilder: (_, __) => SizedBox(height: 12.sh),
                    itemBuilder: (context, index) {
                      final client = clients[index];
                      final otherUserId = client["userId"] as String;
                      final otherUserName = client["name"] as String;
                      final otherUserPhoto = client["photoUrl"] as String?;
                      final chatId = client["chatId"] as String;

                      return ListTile(
                        onTap: () async {
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
                        contentPadding: EdgeInsets.symmetric(horizontal: 16.sw, vertical: 8.sh),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.sw),
                          side: BorderSide(color: purple.withValues(alpha:0.05)),
                        ),
                        tileColor: Colors.white,
                        leading: CircleAvatar(
                          radius: 24.sw,
                          backgroundColor: purple.withValues(alpha:0.1),
                          backgroundImage: otherUserPhoto != null ? NetworkImage(otherUserPhoto) : null,
                          child: otherUserPhoto == null ? Icon(Icons.person, color: purple, size: 24.sp) : null,
                        ),
                        title: Text(otherUserName, style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 16.sp)),
                        trailing: Container(
                          padding: EdgeInsets.all(8.sw),
                          decoration: BoxDecoration(
                            color: orange.withValues(alpha:0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.send_rounded, color: orange, size: 20.sp),
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
    final user = FirebaseAuth.instance.currentUser;
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
        ClipRRect(
          borderRadius: BorderRadius.circular(50.sw),
          child: Container(
            width: 80.sw,
            height: 80.sw,
            color: const Color(0xFFD9D9D9),
            child: _photoUrl != null
                ? Image.network(_photoUrl!, fit: BoxFit.cover)
                : Image.asset('assets/Logos/profile_placeholder.png', scale: 2),
          ),
        ),
        SizedBox(height: 10.sh),
        Text(
          _name ?? 'Hidden Pantry',
          style: TextStyle(
            color: purple,
            fontSize: 15.sp,
            fontWeight: FontWeight.bold,
            fontFamily: 'Satoshi',
          ),
        ),
        SizedBox(height: 5.sh),
        Text(
          _bio ?? 'Passionate about cooking.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: purple,
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
            fontFamily: 'Satoshi',
          ),
        ),
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
          return const Center(child: CircularProgressIndicator());
        }
        
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.only(top: 40.sh),
              child: Text(
                "You haven't uploaded any recipes yet.",
                style: TextStyle(color: purple.withValues(alpha:0.6), fontFamily: "Satoshi", fontSize: 14.sp),
              ),
            ),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 157 / 231,
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecipeDetailsScreen(recipe: recipe),
                  ),
                );
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
}




