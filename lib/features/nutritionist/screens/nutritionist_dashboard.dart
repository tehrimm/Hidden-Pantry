import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';
import 'package:hidden_pantry_app/core/widgets/nutritionist_bottom_nav.dart';
import 'package:hidden_pantry_app/features/nutritionist/screens/client_plans.dart';
import 'package:hidden_pantry_app/core/services/notification_service.dart';
import 'package:hidden_pantry_app/features/nutritionist/screens/nutritionist_settings.dart';
import 'package:hidden_pantry_app/core/services/view_mode_service.dart';
import 'package:hidden_pantry_app/core/widgets/main_navigation_shell.dart';
import 'package:hidden_pantry_app/features/nutritionist/screens/meal_plan_creator.dart';
import 'package:hidden_pantry_app/features/nutritionist/screens/payout_management.dart';
import 'package:hidden_pantry_app/features/nutritionist/screens/nutritionist_chat_list.dart';
import 'package:hidden_pantry_app/features/nutritionist/screens/nutritionist_posts_screen.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';
import 'package:hidden_pantry_app/features/nutritionist/services/nutritionist_service.dart';
import 'package:hidden_pantry_app/features/nutritionist/widgets/recipe_selection_sheet.dart';
import 'package:hidden_pantry_app/features/nutritionist/widgets/share_recipe_post_dialog.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/utils/glass_dialog.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

class NutritionistDashboard extends StatefulWidget {
  const NutritionistDashboard({super.key});

  @override
  State<NutritionistDashboard> createState() => _NutritionistDashboardState();
}

class _NutritionistDashboardState extends State<NutritionistDashboard> {
  final Color bg = const Color(0xFFFFF7F2);
  final Color purple = const Color(0xFF321B3A);
  final Color orange = const Color(0xFFFF8C5A);
  final Color brown = const Color(0xFF5D4037);
  final Color accent = const Color(0xFF7B61FF);

  int bottomIndex = 0; // 0 dashboard, 1 client, 2 plus, 3 plans, 4 message
  String? fullName;
  String? photoUrl;
  bool loadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => loadingProfile = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection("nutritionists")
          .doc(user.uid)
          .get();
      
      final data = doc.data();
      if (mounted) {
        setState(() {
          fullName = data?['fullName'] ?? user.displayName ?? "Nutritionist";
          photoUrl = data?['photoUrl'] ?? user.photoURL;
          loadingProfile = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          fullName = user.displayName ?? "Nutritionist";
          photoUrl = user.photoURL;
          loadingProfile = false;
        });
      }
    }
  }

  void _onBottomTap(int i) {
    if (i == 2) {
      _showPlusMenu();
      return;
    }
    setState(() => bottomIndex = i);
  }

  void _showPlusMenu() {
    const Color actionOrange = Color(0xFFE48E5B);

    final actions = [
      {"icon": Icons.restaurant_menu_rounded, "title": "Create New Meal Plan", "subtitle": "Design a custom plan for your client", "action": "plan"},
      {"icon": Icons.auto_stories_rounded, "title": "Share Meal Plan", "subtitle": "Send personalized recommendations", "action": "share_meal_plan"},
      {"icon": Icons.add_box_outlined, "title": "Make a Post", "subtitle": "Share health advice, recipes, or updates", "action": "tip"},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF9E3D5).withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
            boxShadow: [
              BoxShadow(color: purple.withValues(alpha: 0.1), blurRadius: 30, offset: const Offset(0, -10)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(color: purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.bolt_rounded, color: orange, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "Quick Actions",
                      style: TextStyle(color: purple, fontSize: 22, fontWeight: FontWeight.w900, fontFamily: "Satoshi"),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 24),
                  child: Column(
                    children: actions.asMap().entries.map((entry) {
                      final index = entry.key;
                      final a = entry.value;
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: Duration(milliseconds: 500 + (index * 100)),
                        curve: Curves.easeOutBack,
                        builder: (context, value, child) => Opacity(
                          opacity: value.clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(0, 40 * (1 - value)),
                            child: child,
                          ),
                        ),
                        child: _actionItem(a),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  

  Widget _actionItem(Map<String, dynamic> action) {
    const Color actionOrange = Color(0xFFEF8A54);
    const Color iconColor = Color(0xFF74503C);
    const Color subTextColor = Color(0xFFBFA89A);

    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: purple.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            Navigator.pop(context);
            final key = action["action"] as String;
            if (key == "plan") {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const MealPlanCreatorScreen()));
            } else if (key == "tip") {
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted) _showMakePostDialog();
              });
            } else if (key == "share_meal_plan") {
              _showMealPlanSelectionSheet();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [actionOrange.withValues(alpha: 0.1), actionOrange.withValues(alpha: 0.05)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: actionOrange.withValues(alpha: 0.1)),
                  ),
                  child: Icon(action["icon"] as IconData, color: actionOrange, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action["title"] as String,
                        style: TextStyle(color: purple, fontWeight: FontWeight.w800, fontSize: 16, fontFamily: "Satoshi"),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        action["subtitle"] as String,
                        style: TextStyle(color: subTextColor, fontSize: 12, height: 1.4, fontFamily: "Satoshi"),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9E3D5).withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: iconColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMakePostDialog({File? initialImage, File? initialDoc, String? initialRecipeId, String? initialRecipeTitle, String? initialRecipeImageUrl}) {
    final TextEditingController tipController = TextEditingController();
    String? selectedPlanId;
    String? selectedPlanTitle;
    String? selectedRecipeId = initialRecipeId;
    String? selectedRecipeTitle = initialRecipeTitle;
    String? selectedRecipeImageUrl = initialRecipeImageUrl;
    File? attachedImage = initialImage;
    File? attachedDoc = initialDoc;
    bool isPosting = false;
    int selectedTier = 0; // 0: Free, 1: Silver, 2: Gold, 3: Platinum
    
    GlassDialog.show(
      context: context,
      builder: (context) {

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: bg,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                   Text("Make a Post", style: TextStyle(color: purple, fontWeight: FontWeight.bold)),
                   const Spacer(),
                   IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close, color: purple.withValues(alpha:0.3))),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Share health advice, meal plans, or updates with your community.",
                        style: TextStyle(color: purple.withValues(alpha:0.6), fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      // Main Text Field
                      TextField(
                        controller: tipController,
                        maxLines: 5,
                        enabled: !isPosting,
                        decoration: InputDecoration(
                          hintText: "What's on your mind?...",
                          filled: true,
                          fillColor: const Color(0xFFF9E3D5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Attachments List (Previews)
                      if (selectedPlanId != null || attachedImage != null || attachedDoc != null || selectedRecipeId != null) ...[
                        Text("Attachments", style: TextStyle(color: purple, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (selectedRecipeId != null)
                          _attachmentPreview(
                            label: selectedRecipeTitle ?? "Recipe",
                            icon: Icons.restaurant_rounded,
                            onRemove: () => setState(() => selectedRecipeId = selectedRecipeTitle = selectedRecipeImageUrl = null),
                          ),
                        if (selectedPlanId != null)
                           _attachmentPreview(
                             label: selectedPlanTitle ?? "Meal Plan",
                             icon: Icons.restaurant_menu_rounded,
                             onRemove: () => setState(() => selectedPlanId = selectedPlanTitle = null),
                           ),
                         if (attachedImage != null)
                           Padding(
                             padding: const EdgeInsets.only(bottom: 8),
                             child: Stack(
                               children: [
                                 ClipRRect(
                                   borderRadius: BorderRadius.circular(12),
                                   child: Image.file(attachedImage!, height: 100, width: double.infinity, fit: BoxFit.cover),
                                 ),
                                 Positioned(
                                   top: 5, right: 5,
                                   child: CircleAvatar(
                                     radius: 12, backgroundColor: Colors.black54,
                                     child: IconButton(
                                       padding: EdgeInsets.zero,
                                       icon: const Icon(Icons.close, size: 14, color: Colors.white),
                                       onPressed: () => setState(() => attachedImage = null),
                                     ),
                                   ),
                                 )
                               ],
                             ),
                           ),
                         if (attachedDoc != null)
                           _attachmentPreview(
                             label: attachedDoc!.path.split('/').last,
                             icon: Icons.description_rounded,
                             onRemove: () => setState(() => attachedDoc = null),
                           ),
                         const SizedBox(height: 12),
                      ],

                      // Attachment Buttons Row
                      Text("Add to your post", style: TextStyle(color: purple, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                             _attachmentButton(
                               icon: Icons.restaurant_rounded,
                               label: "Recipe",
                               onTap: () => _selectRecipeForPost(setState, (id, title, imageUrl) {
                                 setState(() {
                                   selectedRecipeId = id;
                                   selectedRecipeTitle = title;
                                   selectedRecipeImageUrl = imageUrl;
                                 });
                               }),
                             ),
                             const SizedBox(width: 8),
                             _attachmentButton(
                               icon: Icons.restaurant_menu_rounded,
                               label: "Meal Plan",
                               onTap: () => _selectPlanForPost(setState, (id, title) {
                                 setState(() {
                                    selectedPlanId = id;
                                    selectedPlanTitle = title;
                                 });
                               }),
                             ),
                             const SizedBox(width: 8),
                             _attachmentButton(
                               icon: Icons.image_rounded,
                               label: "Photo",
                               onTap: () async {
                                 final picker = ImagePicker();
                                 final picked = await picker.pickImage(source: ImageSource.gallery);
                                 if (picked != null) {
                                   setState(() => attachedImage = File(picked.path));
                                 }
                               },
                             ),
                             const SizedBox(width: 8),
                             _attachmentButton(
                               icon: Icons.attach_file_rounded,
                               label: "Document",
                               onTap: () async {
                                 final result = await FilePicker.platform.pickFiles();
                                 if (result != null && result.files.single.path != null) {
                                   setState(() => attachedDoc = File(result.files.single.path!));
                                 }
                               },
                             ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      Text(
                        "Who can see this?",
                        style: TextStyle(color: purple, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        value: selectedTier,
                        isExpanded: true,
                        decoration: InputDecoration(
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xFFF9E3D5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        dropdownColor: const Color(0xFFF9E3D5),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text("Free (Public)", style: TextStyle(color: Color(0xFF462F4D), fontFamily: "Satoshi"))),
                          DropdownMenuItem(value: 1, child: Text("Tier 1 (Silver Sub)", style: TextStyle(color: Color(0xFF462F4D), fontFamily: "Satoshi"))),
                          DropdownMenuItem(value: 2, child: Text("Tier 2 (Gold Sub)", style: TextStyle(color: Color(0xFF462F4D), fontFamily: "Satoshi"))),
                          DropdownMenuItem(value: 3, child: Text("Tier 3 (Platinum)", style: TextStyle(color: Color(0xFF462F4D), fontFamily: "Satoshi"))),
                        ],
                        onChanged: isPosting ? null : (v) => setState(() => selectedTier = v ?? 0),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                if (!isPosting)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Cancel", style: TextStyle(color: purple.withValues(alpha:0.6))),
                  ),
                ElevatedButton(
                  onPressed: (isPosting || (tipController.text.trim().isEmpty && attachedImage == null && attachedDoc == null && selectedPlanId == null && selectedRecipeId == null))
                      ? null
                      : () async {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user == null) return;

                          setState(() => isPosting = true);

                          try {
                            String? imageUrl;
                            String? docUrl;

                            // Handle File Uploads
                            if (attachedImage != null) {
                              imageUrl = await const NutritionistService().uploadPostFile(attachedImage!, user.uid);
                            }
                            if (attachedDoc != null) {
                              docUrl = await const NutritionistService().uploadPostFile(attachedDoc!, user.uid);
                            }

                            final Map<String, dynamic> postData = {
                              "content": tipController.text.trim(),
                              "timestamp": FieldValue.serverTimestamp(),
                              "minTier": selectedTier,
                              "likes": 0,
                              "commentCount": 0,
                              "likedBy": [],
                              "type": "unified_post",
                            };

                            if (selectedPlanId != null) {
                              postData["mealPlanId"] = selectedPlanId;
                              postData["hasMealPlan"] = true;
                              postData["mealPlanTitle"] = selectedPlanTitle;
                            }
                            if (selectedRecipeId != null) {
                              postData["recipeId"] = selectedRecipeId;
                              postData["hasRecipe"] = true;
                              postData["recipeName"] = selectedRecipeTitle;
                              postData["recipeImageUrl"] = selectedRecipeImageUrl;
                            }
                            if (imageUrl != null) {
                              postData["imageUrl"] = imageUrl;
                              postData["hasImage"] = true;
                            }
                            if (docUrl != null) {
                              postData["docUrl"] = docUrl;
                              postData["hasDoc"] = true;
                            }

                            await FirebaseFirestore.instance
                                .collection("nutritionists")
                                .doc(user.uid)
                                .collection("tips")
                                .add(postData)
                                .timeout(const Duration(seconds: 30));

                            // Trigger Follower Notifications
                            NotificationService().notifyFollowersOfPost(
                              nutritionistId: user.uid,
                              nutritionistName: fullName ?? "Nutritionist",
                              nutritionistPhotoUrl: photoUrl,
                              content: tipController.text.trim(),
                              postId: "new_post", // Add real ID if needed
                            );

                            if (context.mounted) {
                              Navigator.of(context).pop();
                              Toaster.show(context, "Posted successfully!");
                            }
                          } catch (e) {
                            if (context.mounted) {
                              setState(() => isPosting = false);
                              Toaster.show(context, "Failed to post: $e", isError: true);
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: orange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(100, 45),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isPosting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Post to Community", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _attachmentButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: purple.withValues(alpha:0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: purple.withValues(alpha:0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: orange, size: 18),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: purple, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _attachmentPreview({required String label, required IconData icon, required VoidCallback onRemove}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9E3D5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: orange.withValues(alpha:0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: orange, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(color: purple, fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
          IconButton(
            padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            icon: Icon(Icons.cancel_rounded, color: purple.withValues(alpha:0.3), size: 18),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }

  

  void _selectPlanForPost(StateSetter dialogSetState, Function(String, String) onSelect) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              width: 50, height: 5,
              decoration: BoxDecoration(color: orange.withValues(alpha:0.3), borderRadius: BorderRadius.circular(3)),
            ),
            Text("Select a Meal Plan", style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("nutritionists")
                    .doc(user.uid)
                    .collection("meal_plans")
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) return const Center(child: Text("No meal plans found."));

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final plan = docs[index].data() as Map<String, dynamic>;
                      final id = docs[index].id;
                      final title = plan["title"] ?? "Untitled";
                      return ListTile(
                        onTap: () {
                          onSelect(id, title);
                          Navigator.pop(context);
                        },
                        leading: Icon(Icons.restaurant_menu_rounded, color: orange),
                        title: Text(title, style: TextStyle(color: purple, fontWeight: FontWeight.bold)),
                        subtitle: Text("${plan['duration'] ?? 0} Days", style: TextStyle(color: purple.withValues(alpha:0.5))),
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

  void _selectRecipeForPost(StateSetter dialogSetState, Function(String, String, String?) onSelect) {
    _showRecipeSelectionSheet(onSelected: onSelect);
  }

  

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NutritionistSettingsScreen()),
    ).then((_) => _loadProfile());
  }

  Future<void> _switchToUserView() async {
    await ViewModeService().setUserView(true);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => MainNavigationShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    return PopScope(
      canPop: bottomIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (bottomIndex != 0) {
          setState(() => bottomIndex = 0);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        extendBody: true,
        body: ClipRRect(
          borderRadius: BorderRadius.circular(30.sw),
          child: Container(
            color: bg,
            child: Stack(
              children: [
                const _DashboardBackgroundPattern(),
                PatternBackground(opacity: 0.6),
                SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      if (bottomIndex != 4) _topRow(),
                      Expanded(
                        child: IndexedStack(
                          index: bottomIndex > 2 ? bottomIndex - 1 : bottomIndex,
                          children: [
                            _dashboardHome(),
                            const NutritionistPostsScreen(),
                            // skip plus (index 2)
                            const ClientPlansScreen(),
                            const NutritionistChatListScreen(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: NbBottomNav(
          currentIndex: bottomIndex,
          onTap: _onBottomTap,
          orange: orange,
        ),
      ),
    );
  }

  Widget _topRow() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 22.sw, vertical: 16.sh),
      child: Row(
        children: [
          GestureDetector(
            onTap: _openSettings,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(50.sw),
              child: Container(
                width: 50.sw,
                height: 50.sw,
                color: const Color(0xFFD9D9D9),
                child: photoUrl != null && photoUrl!.startsWith("http")
                    ? Image.network(
                        photoUrl!, 
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(child: Icon(Icons.person_rounded, color: purple, size: 28.sw)),
                      )
                    : Center(child: Icon(Icons.person_rounded, color: purple, size: 28.sw)),
              ),
            ),
          ),
          const Spacer(),
          // View Switcher Button (Restaurant Icon)
          GestureDetector(
            onTap: _switchToUserView,
            child: Container(
              padding: EdgeInsets.all(10.sw),
              decoration: BoxDecoration(
                color: const Color(0xFFF9E3D5),
                borderRadius: BorderRadius.circular(15.sw),
                boxShadow: [
                  BoxShadow(
                    color: purple.withValues(alpha:0.05),
                    blurRadius: 10.sw,
                  ),
                ],
              ),
              child: Icon(Icons.restaurant_rounded, color: orange, size: 24.sw),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashboardHome() {
    final hour = DateTime.now().hour;
    String greeting = "Good morning";
    if (hour >= 12 && hour < 17) greeting = "Good afternoon";
    else if (hour >= 17) greeting = "Good evening";

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 22.sw),
      physics: const BouncingScrollPhysics(),
      children: [
        SizedBox(height: 20.sh),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(-20 * (1 - value), 0),
              child: child,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "$greeting,",
                style: TextStyle(
                  color: purple.withValues(alpha: 0.6),
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Satoshi",
                ),
              ),
              Text(
                loadingProfile ? "..." : (fullName ?? "Nutritionist"),
                style: TextStyle(
                  color: purple,
                  fontSize: 36.sp,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  fontFamily: "Satoshi",
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 32.sh),
        _statsGrid(),
        SizedBox(height: 32.sh),
        _subscriptionTiersSection(),
        SizedBox(height: 32.sh),
        _upcomingAppointments(),
        SizedBox(height: 32.sh),
        _recentReviewsSection(),
        SizedBox(height: 120.sh), // Spacing for bottom nav
      ],
    );
  }

  Widget _statsGrid() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("subscriptions")
                    .where("nutritionistId", isEqualTo: uid)
                    .where("status", whereIn: ["active", "trialing"])
                    .snapshots(),
                builder: (context, snap) {
                  final Set<String> uniqueUsers = {};
                  final now = DateTime.now();
                  if (snap.hasData) {
                    for (var d in snap.data!.docs) {
                      final data = d.data() as Map<String, dynamic>;
                      final userId = data["userId"];
                      final Timestamp? expiryDate = data["expiryDate"] as Timestamp?;
                      
                      // Active check: must have valid status and not be expired
                      if (userId != null && (expiryDate != null && expiryDate.toDate().isAfter(now))) {
                        uniqueUsers.add(userId);
                      }
                    }
                  }
                  return _animatedStatCard(
                    label: "Active Clients", 
                    value: uniqueUsers.length.toString(), 
                    icon: Icons.people_rounded,
                    delay: 100,
                  );
                }
              ),
            ),
            SizedBox(width: 16.sw),
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection("nutritionists").doc(uid).snapshots(),
                builder: (context, snap) {
                  final data = snap.data?.data() as Map<String, dynamic>? ?? {};
                  final double ratingSum = (data['total_rating_sum'] ?? 0.0).toDouble();
                  final int reviewCount = (data['total_review_count'] ?? 0);
                  double avg = 0.0;
                  if (reviewCount > 0) avg = ratingSum / reviewCount;
                  
                  return _animatedStatCard(
                    label: "Professional Rating", 
                    value: avg > 0 ? avg.toStringAsFixed(1) : "0.0", 
                    icon: Icons.star_rounded,
                    subtitle: "$reviewCount reviews total",
                    delay: 200,
                  );
                }
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("nutritionists")
                    .doc(uid)
                    .collection("subscription_plans")
                    .snapshots(),
                builder: (context, snap) {
                  final count = snap.data?.docs.length ?? 0;
                  return _animatedStatCard(
                    label: "Total Plans", 
                    value: count.toString(), 
                    icon: Icons.restaurant_menu_rounded,
                    delay: 250,
                  );
                }
              ),
            ),
            SizedBox(width: 16.sw),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("nutritionists")
                    .doc(uid)
                    .collection("tips")
                    .snapshots(),
                builder: (context, snap) {
                  final count = snap.data?.docs.length ?? 0;
                  return _animatedStatCard(
                    label: "Community Posts", 
                    value: count.toString(), 
                    icon: Icons.add_box_outlined,
                    delay: 300,
                  );
                }
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection("nutritionists").doc(uid).snapshots(),
          builder: (context, snap) {
            final data = snap.data?.data() as Map<String, dynamic>? ?? {};
            final total = (data["totalEarnings"] ?? 0.0).toDouble();
            final bool loading = snap.connectionState == ConnectionState.waiting;

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("subscriptions")
                  .where("nutritionistId", isEqualTo: uid)
                  .where("status", whereIn: ["active", "trialing"])
                  .snapshots(),
              builder: (context, subSnap) {
                double projectedMonthly = 0;
                final now = DateTime.now();
                if (subSnap.hasData && subSnap.data != null) {
                  final Map<String, double> userPayments = {};
                  for (var doc in subSnap.data!.docs) {
                    final d = doc.data() as Map<String, dynamic>;
                    final userId = d["userId"];
                    final price = (d["price"] ?? 0).toDouble();
                    final Timestamp? expiryDate = d["expiryDate"] as Timestamp?;

                    // Fix: Only count projected revenue for non-expired subscriptions
                    if (userId != null && (expiryDate == null || expiryDate.toDate().isAfter(now))) {
                      if (!userPayments.containsKey(userId) || userPayments[userId]! < price) {
                        userPayments[userId] = price;
                      }
                    }
                  }
                  for (var p in userPayments.values) {
                    projectedMonthly += p;
                  }
                }

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const PayoutManagementScreen()),
                              );
                            },
                            child: _animatedStatCard(
                              label: "Net Earnings", 
                              value: loading ? "..." : "Rs. ${(total * 0.9).toInt()}", 
                              icon: Icons.monetization_on_rounded,
                              subtitle: "After 10% Fee",
                              delay: 300,
                            ),
                          ),
                        ),
                        SizedBox(width: 16.sw),
                         Expanded(
                          child: _animatedStatCard(
                            label: "Projected Net/Mo", 
                            value: "Rs. ${(projectedMonthly * 0.9).toInt()}", 
                            icon: Icons.trending_up_rounded,
                            subtitle: "90% Share (Active)",
                            delay: 400,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.sh),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _animatedStatCard({
    required String label,
    required String value,
    required IconData icon,
    String? subtitle,
    required int delay,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + delay),
      curve: Curves.easeOutQuint,
      builder: (context, animValue, child) {
        return Opacity(
          opacity: animValue,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - animValue)),
            child: child,
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(20.sw),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(28.sw),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: purple.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: EdgeInsets.all(8.sw),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF2EA),
                borderRadius: BorderRadius.circular(10.sw),
              ),
              child: Icon(icon, color: orange, size: 20.sw),
            ),
            SizedBox(height: 12.sh),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: Text(
                    value,
                    key: ValueKey(value),
                    style: TextStyle(
                      color: purple,
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w900,
                      fontFamily: "Satoshi",
                    ),
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: purple.withValues(alpha: 0.6),
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    fontFamily: "Satoshi",
                  ),
                ),
                if (subtitle != null) ...[
                  SizedBox(height: 2.sh),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: orange,
                      fontSize: 9.sp,
                      fontWeight: FontWeight.bold,
                      fontFamily: "Satoshi",
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, {String? subtitle}) {
    return Container(
      padding: EdgeInsets.all(16.sw), 
      decoration: BoxDecoration(
        color: const Color(0xFFF9E3D5), 
        borderRadius: BorderRadius.circular(24.sw),
        boxShadow: [
          BoxShadow(
            color: purple.withValues(alpha:0.05),
            blurRadius: 15.sw,
            offset: Offset(0, 8.sh),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: EdgeInsets.all(8.sw),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF2EA), // Updated to requested color
              borderRadius: BorderRadius.circular(10.sw),
            ),
            child: Icon(icon, color: orange, size: 20.sw),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: purple,
                  fontSize: 20.sp, // Slightly reduced to prevent overflow
                  fontWeight: FontWeight.w900,
                  fontFamily: "Satoshi",
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: purple.withValues(alpha:0.6),
                  fontSize: 11.sp, // Slightly reduced to prevent overflow
                  fontWeight: FontWeight.w500,
                  fontFamily: "Satoshi",
                ),
              ),
              if (subtitle != null) ...[
                SizedBox(height: 2.sh),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: orange,
                    fontSize: 9.sp,
                    fontWeight: FontWeight.bold,
                    fontFamily: "Satoshi",
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _upcomingAppointments() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Schedule",
              style: TextStyle(
                color: purple,
                fontSize: 22.sp,
                fontWeight: FontWeight.w900,
                fontFamily: "Satoshi",
              ),
            ),
          ],
        ),
        SizedBox(height: 16.sh),
        // First get all chats the nutritionist is part of
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("chats")
              .where("participants", arrayContains: user.uid)
              .snapshots(),
          builder: (context, chatSnap) {
            if (!chatSnap.hasData || chatSnap.data!.docs.isEmpty) {
              return _emptyScheduleCard();
            }

            final chatIds = chatSnap.data!.docs.map((d) => d.id).toList();

            // Collect all meeting messages from all chats
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchUpcomingMeetings(chatIds),
              builder: (context, meetingSnap) {
                if (meetingSnap.connectionState == ConnectionState.waiting) {
                  return Center(child: Padding(
                    padding: EdgeInsets.all(20.sw),
                    child: CircularProgressIndicator(color: orange, strokeWidth: 2.sw),
                  ));
                }

                final meetings = meetingSnap.data ?? [];
                if (meetings.isEmpty) {
                  return _emptyScheduleCard();
                }

                // Show up to 3 upcoming
                final display = meetings.take(3).toList();

                return Column(
                  children: display.asMap().entries.map((entry) {
                    final index = entry.key;
                    final m = entry.value;
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 600 + (index * 100)),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) => Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: child,
                        ),
                      ),
                      child: _sessionCard(m),
                    );
                  }).toList(),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _emptyScheduleCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 32.sh),
      decoration: BoxDecoration(
        color: orange.withValues(alpha:0.05),
        borderRadius: BorderRadius.circular(24.sw),
        border: Border.all(color: orange.withValues(alpha:0.1), width: 1.sw),
      ),
      child: Column(
        children: [
          Icon(Icons.calendar_month_rounded, color: orange.withValues(alpha:0.3), size: 40.sw),
          SizedBox(height: 12.sh),
          Text(
            "No upcoming sessions",
            style: TextStyle(
              color: purple.withValues(alpha:0.4),
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              fontFamily: "Satoshi",
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchUpcomingMeetings(List<String> chatIds) async {
    final List<Map<String, dynamic>> allMeetings = [];

    for (final chatId in chatIds) {
      try {
        final msgSnap = await FirebaseFirestore.instance
            .collection("chats")
            .doc(chatId)
            .collection("messages")
            .where("type", isEqualTo: "meeting")
            .orderBy("meetingDate", descending: false)
            .get();

        for (final doc in msgSnap.docs) {
          final data = doc.data();
          DateTime? meetingDate;
          if (data["meetingDate"] is Timestamp) {
            meetingDate = (data["meetingDate"] as Timestamp).toDate();
          }
          if (meetingDate == null) continue;
          
          // Parse specific time
          int hour = 10;
          int minute = 0;
          final timeStr = data["meetingTime"] as String? ?? "10:00 AM";
          final regex = RegExp(r'(\d+):(\d+)\s*([a|p]m)?', caseSensitive: false);
          final match = regex.firstMatch(timeStr);
          if (match != null) {
            hour = int.tryParse(match.group(1) ?? "10") ?? 10;
            minute = int.tryParse(match.group(2) ?? "0") ?? 0;
            final period = match.group(3)?.toLowerCase();
            if (period == 'pm' && hour < 12) hour += 12;
            if (period == 'am' && hour == 12) hour = 0;
          }
          
          final exactMeetingTime = DateTime(
            meetingDate.year,
            meetingDate.month,
            meetingDate.day,
            hour,
            minute,
          );

          // Check if meeting has completely passed (add 1 hr duration tolerance)
          final meetingEnd = exactMeetingTime.add(const Duration(hours: 1));
          if (DateTime.now().isAfter(meetingEnd)) {
            // Delete from Firestore
            try {
              FirebaseFirestore.instance
                  .collection("chats")
                  .doc(chatId)
                  .collection("messages")
                  .doc(doc.id)
                  .delete();
            } catch (e) {
              debugPrint("Failed to delete expired meeting: $e");
            }
            continue; // Skip adding to upcoming list
          }

          // Get client name
          final participants = chatId.replaceFirst("chat_", "").split("_");
          String clientId = "";
          for (var p in participants) {
            if (p != FirebaseAuth.instance.currentUser?.uid) {
              clientId = p;
              break;
            }
          }

          String clientName = "Client";
          if (clientId.isNotEmpty) {
            try {
              final userDoc = await FirebaseFirestore.instance.collection("users").doc(clientId).get();
              if (userDoc.exists) {
                clientName = userDoc.data()?["fullName"] ?? "Client";
              }
            } catch (_) {}
          }

          allMeetings.add({
            "date": meetingDate,
            "time": data["meetingTime"] ?? "",
            "notes": data["notes"] ?? "",
            "clientName": clientName,
            "chatId": chatId,
          });
        }
      } catch (e) {
        debugPrint("Error fetching meetings from $chatId: $e");
      }
    }

    // Sort by date ascending
    allMeetings.sort((a, b) => (a["date"] as DateTime).compareTo(b["date"] as DateTime));
    return allMeetings;
  }

  Widget _sessionCard(Map<String, dynamic> meeting) {
    final DateTime date = meeting["date"];
    final String time = meeting["time"];
    final String notes = meeting["notes"];
    final String clientName = meeting["clientName"];

    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final isTomorrow = date.year == now.year && date.month == now.month && date.day == now.day + 1;

    String dateLabel;
    if (isToday) {
      dateLabel = "Today";
    } else if (isTomorrow) {
      dateLabel = "Tomorrow";
    } else {
      dateLabel = "${_monthName(date.month)} ${date.day}, ${date.year}";
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12.sh),
      padding: EdgeInsets.all(18.sw),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.sw),
        boxShadow: [
          BoxShadow(color: purple.withValues(alpha:0.05), blurRadius: 10.sw, offset: Offset(0, 4.sh)),
        ],
      ),
      child: Row(
        children: [
          // Date badge
          Container(
            width: 54.sw,
            height: 60.sh,
            decoration: BoxDecoration(
              color: isToday ? orange : orange.withValues(alpha:0.12),
              borderRadius: BorderRadius.circular(14.sw),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  date.day.toString(),
                  style: TextStyle(
                    color: isToday ? Colors.white : orange,
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Satoshi",
                  ),
                ),
                Text(
                  _monthName(date.month).substring(0, 3).toUpperCase(),
                  style: TextStyle(
                    color: isToday ? Colors.white.withValues(alpha:0.8) : orange.withValues(alpha:0.7),
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 16.sw),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Consultation with $clientName",
                  style: TextStyle(color: purple, fontSize: 14.sp, fontWeight: FontWeight.bold, fontFamily: "Satoshi"),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.sh),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 14.sw, color: orange),
                    SizedBox(width: 4.sw),
                    Text(
                      "$dateLabel • $time",
                      style: TextStyle(color: purple.withValues(alpha:0.5), fontSize: 12.sp, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                if (notes.isNotEmpty) ...[
                  SizedBox(height: 4.sh),
                  Text(
                    notes,
                    style: TextStyle(color: purple.withValues(alpha:0.4), fontSize: 11.sp, fontStyle: FontStyle.italic),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          // Status indicator
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.sw, vertical: 5.sh),
            decoration: BoxDecoration(
              color: isToday ? orange.withValues(alpha:0.1) : purple.withValues(alpha:0.06),
              borderRadius: BorderRadius.circular(8.sw),
            ),
            child: Text(
              isToday ? "Today" : (isTomorrow ? "Tomorrow" : "Upcoming"),
              style: TextStyle(
                color: isToday ? orange : purple.withValues(alpha:0.5),
                fontSize: 10.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _monthName(int month) {
    const months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
    return months[month - 1];
  }


  Widget _clientInsights() {
    final user = FirebaseAuth.instance.currentUser;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutQuint,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: child,
        ),
      ),
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 10.sh),
        padding: EdgeInsets.all(26.sw),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [purple, const Color(0xFF4A2B55)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(32.sw),
          boxShadow: [
            BoxShadow(
              color: purple.withValues(alpha: 0.3),
              blurRadius: 25,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.sw),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12.sw),
                  ),
                  child: Icon(Icons.auto_graph_rounded, color: orange, size: 22.sw),
                ),
                SizedBox(width: 14.sw),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Subscriber Analytics",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w900,
                          fontFamily: "Satoshi",
                        ),
                      ),
                      Text(
                        "Monthly performance breakdown",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12.sp,
                          fontFamily: "Satoshi",
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 32.sh),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("subscriptions")
                  .where("nutritionistId", isEqualTo: user?.uid)
                  .where("status", whereIn: ["active", "trialing"])
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Container(
                    height: 150.sh,
                    alignment: Alignment.center,
                    child: Text(
                      "Analytics will appear here once you have active subscribers.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13.sp, height: 1.4),
                    ),
                  );
                }

                final Map<String, int> userTier = {};
                final Map<String, double> userPrice = {};
                final now = DateTime.now();

                for (var doc in snapshot.data!.docs) {
                  final d = doc.data() as Map<String, dynamic>;
                  final uid = d["userId"];
                  final Timestamp? expiryDate = d["expiryDate"] as Timestamp?;
                  if (uid == null) continue;
                  if (expiryDate != null && expiryDate.toDate().isBefore(now)) continue;

                  int tier = 0;
                  final rawTier = d["tierLevel"];
                  if (rawTier is num) tier = rawTier.toInt();
                  else if (rawTier is String) tier = int.tryParse(rawTier) ?? 0;

                  final double price = (d["price"] ?? 0).toDouble();

                  if (!userTier.containsKey(uid) || tier > userTier[uid]!) {
                    userTier[uid] = tier;
                    userPrice[uid] = price;
                  }
                }

                final Map<int, double> tierRevenue = {1: 0, 2: 0, 3: 0};
                final Map<int, int> tierCounts = {1: 0, 2: 0, 3: 0};

                for (var entry in userTier.entries) {
                  final tier = entry.value;
                  if (tier >= 1 && tier <= 3) {
                    tierCounts[tier] = (tierCounts[tier] ?? 0) + 1;
                    tierRevenue[tier] = (tierRevenue[tier] ?? 0) + (userPrice[entry.key] ?? 0);
                  }
                }

                final int totalClients = userTier.length;
                double maxRev = tierRevenue.values.fold(1.0, (a, b) => a > b ? a : b);

                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _tierBar("Silver", tierRevenue[1]!, tierCounts[1]!, const Color(0xFFC0C0C0), maxRev),
                        _tierBar("Gold", tierRevenue[2]!, tierCounts[2]!, const Color(0xFFFFD700), maxRev),
                        _tierBar("Platinum", tierRevenue[3]!, tierCounts[3]!, const Color(0xFFB388FF), maxRev),
                      ],
                    ),
                    SizedBox(height: 32.sh),
                    Container(
                      padding: EdgeInsets.all(20.sw),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(24.sw),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _summaryItem("Active Clients", totalClients.toString(), Icons.group_outlined),
                          _summaryItem("Avg/Client", "Rs. ${(totalClients == 0 ? 0 : tierRevenue.values.fold(0.0, (a,b)=>a+b) / totalClients).toInt()}", Icons.account_balance_wallet_outlined),
                        ],
                      ),
                    )
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _tierBar(String label, double revenue, int count, Color color, double maxRev) {
    double heightFactor = revenue / maxRev;
    if (heightFactor < 0.1 && revenue > 0) heightFactor = 0.1;
    
    return Column(
      children: [
        Text(
          "Rs. ${revenue.toInt()}", 
          style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.w900)
        ),
        SizedBox(height: 12.sh),
        Container(
          width: 50.sw,
          height: 120.sh * heightFactor,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.6)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16.sw), bottom: Radius.circular(8.sw)),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 5))
            ],
          ),
        ),
        SizedBox(height: 12.sh),
        Text(label, style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w700)),
        Text("$count subs", style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10.sp, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _summaryItem(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(8.sw),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: orange.withValues(alpha: 0.7), size: 16.sw),
          ),
          SizedBox(height: 10.sh),
          Text(value, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16.sp)),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10.sp, fontWeight: FontWeight.bold, fontFamily: "Satoshi")),
        ],
      ),
    );
  }

  

  Widget _subscriptionTiersSection() {
    final user = FirebaseAuth.instance.currentUser;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                "Subscription Plans",
                style: TextStyle(
                  color: purple,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w900,
                  fontFamily: "Satoshi",
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => bottomIndex = 3),
              child: Text(
                "Manage",
                style: TextStyle(
                  color: orange,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("nutritionists")
              .doc(user?.uid)
              .collection("subscription_plans")
              .limit(2)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text("Error loading plans: ${snapshot.error}", style: const TextStyle(color: Colors.red, fontSize: 12));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data == null || snapshot.data!.docs.isEmpty) {
            return _emptyHubCard(user?.uid);
          }
          final docs = snapshot.data!.docs;
          return Column(
            children: docs.map((doc) {
              final plan = doc.data() as Map<String, dynamic>;
              return _planPreviewCard(plan["title"], plan["price"]?.toString() ?? "0");
            }).toList(),
          );
          },
        ),
      ],
    );
  }

  Widget _planPreviewCard(String title, String price) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.sh),
      padding: EdgeInsets.all(22.sw),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(28.sw),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: purple.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.sw),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [orange, orange.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16.sw),
              boxShadow: [
                BoxShadow(color: orange.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: const Icon(Icons.stars_rounded, color: Colors.white, size: 24),
          ),
          SizedBox(width: 18.sw),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: purple,
                    fontWeight: FontWeight.w900,
                    fontSize: 16.sp,
                    fontFamily: "Satoshi",
                  ),
                ),
                SizedBox(height: 2.sh),
                Text(
                  "Monthly Plan",
                  style: TextStyle(
                    color: purple.withValues(alpha: 0.4),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    fontFamily: "Satoshi",
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "Rs. $price",
                style: TextStyle(
                  color: orange,
                  fontWeight: FontWeight.w900,
                  fontSize: 17.sp,
                  fontFamily: "Satoshi",
                ),
              ),
              Text(
                "/month",
                style: TextStyle(
                  color: orange.withValues(alpha: 0.6),
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyHubCard([String? uid]) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.sw),
      decoration: BoxDecoration(
        color: orange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24.sw),
        border: Border.all(color: orange.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Icon(Icons.add_circle_outline_rounded, color: orange.withValues(alpha: 0.3), size: 40.sw),
          SizedBox(height: 12.sh),
          Text(
            "No plans published yet",
            style: TextStyle(
              color: purple.withValues(alpha: 0.4),
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (uid != null) ...[
            const SizedBox(height: 4),
            Text(
              "UID: $uid",
              style: TextStyle(color: purple.withValues(alpha: 0.2), fontSize: 9.sp),
            ),
          ],
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => setState(() => bottomIndex = 3),
            child: Text("Create Your First Tier", style: TextStyle(color: orange, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  


  

  void _showMealPlanSelectionSheet() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3EB),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30.sw)),
        ),
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.only(top: 10.sh, bottom: 20.sh),
              width: 50.sw, height: 5.sh,
              decoration: BoxDecoration(color: orange, borderRadius: BorderRadius.circular(3.sw)),
            ),
            Text("Select Meal Plan to Share", style: TextStyle(color: purple, fontSize: 18.sp, fontWeight: FontWeight.bold)),
            SizedBox(height: 16.sh),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection("nutritionists").doc(user.uid).collection("meal_plans").snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final plans = snapshot.data!.docs;
                  if (plans.isEmpty) return const Center(child: Text("No meal plans created yet."));
                  
                  return ListView.separated(
                    padding: EdgeInsets.all(20.sw),
                    itemCount: plans.length,
                    separatorBuilder: (_, __) => SizedBox(height: 12.sh),
                    itemBuilder: (context, index) {
                      final planDoc = plans[index];
                      final plan = planDoc.data() as Map<String, dynamic>;
                      return ListTile(
                        onTap: () {
                          Navigator.pop(context);
                          _showSelectClientSheet(plan, planDoc.id, benefitTitle: "Meal Plan");
                        },
                        tileColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.sw)),
                        title: Text(plan["title"] ?? "Untitled Plan", style: TextStyle(color: purple, fontWeight: FontWeight.bold)),
                        subtitle: Text("${plan["duration"] ?? 0} Days • ${plan["targetCalories"] ?? 0} kcal"),
                        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16.sw, color: orange),
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

  void _showSelectClientSheet(Map<String, dynamic> planData, String planId, {String? benefitTitle}) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    const Color actionOrange = Color(0xFFE48E5B);
    final Set<String> selectedChatIds = {};
    final Map<String, String> chatIdToUserId = {};

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3EB),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30.sw)),
          ),
          child: Column(
            children: [
              Container(
                margin: EdgeInsets.only(top: 10.sh, bottom: 20.sh),
                width: 50.sw, height: 5.sh,
                decoration: BoxDecoration(color: actionOrange, borderRadius: BorderRadius.circular(3.sw)),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.sw),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      benefitTitle != null ? "Share $benefitTitle" : "Select Clients",
                      style: TextStyle(color: purple, fontSize: 18.sp, fontWeight: FontWeight.bold),
                    ),
                    if (selectedChatIds.isNotEmpty)
                      Text("${selectedChatIds.length} Selected", style: TextStyle(color: actionOrange, fontWeight: FontWeight.bold, fontSize: 14.sp)),
                  ],
                ),
              ),
              SizedBox(height: 16.sh),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchClientsForShare(user.uid, requiredBenefit: benefitTitle ?? "InChat meal plans"),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: actionOrange));
                    }
                    final clients = snapshot.data ?? [];
                    if (clients.isEmpty) return const Center(child: Text("No clients found."));

                    return ListView.separated(
                      padding: EdgeInsets.symmetric(horizontal: 20.sw),
                      itemCount: clients.length,
                      separatorBuilder: (_, __) => SizedBox(height: 12.sh),
                      itemBuilder: (context, index) {
                        final client = clients[index];
                        final otherUserId = client["userId"] as String;
                        final otherUserName = client["name"] as String;
                        final otherUserPhoto = client["photoUrl"] as String?;
                        final chatId = client["chatId"] as String;
                        final isSelected = selectedChatIds.contains(chatId);
                        
                        chatIdToUserId[chatId] = otherUserId;

                        return InkWell(
                          onTap: () {
                            setSheetState(() {
                              if (isSelected) {
                                selectedChatIds.remove(chatId);
                              } else {
                                selectedChatIds.add(chatId);
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected ? actionOrange.withValues(alpha:0.1) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isSelected ? actionOrange : purple.withValues(alpha:0.05)),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24.sw,
                                  backgroundColor: purple.withValues(alpha:0.1),
                                  backgroundImage: (otherUserPhoto != null && otherUserPhoto.startsWith("http")) ? NetworkImage(otherUserPhoto) : null,
                                  child: (otherUserPhoto == null || !otherUserPhoto.startsWith("http")) ? Icon(Icons.person, color: purple, size: 24.sw) : null,
                                ),
                                SizedBox(width: 12.sw),
                                Expanded(child: Text(otherUserName, style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 16.sp))),
                                Icon(
                                  isSelected ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                                  color: isSelected ? actionOrange : purple.withValues(alpha:0.2),
                                  size: 24.sw,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              // Bottom Share Button
              if (selectedChatIds.isNotEmpty)
                Padding(
                  padding: EdgeInsets.all(20.sw),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                         Navigator.pop(context);
                         int count = 0;
                         for (final chatId in selectedChatIds) {
                           try {
                             final uid = chatIdToUserId[chatId]!;
                             await FirebaseFirestore.instance.collection("chats").doc(chatId).collection("messages").add({
                               "senderId": user.uid,
                               "type": "meal_plan",
                               "planData": {...planData, "planId": planId},
                               "timestamp": FieldValue.serverTimestamp(),
                               "read": false,
                             });
                             await FirebaseFirestore.instance.collection("chats").doc(chatId).set({
                               "lastMessage": "Shared a meal plan: ${planData['title'] ?? 'Untitled'}",
                               "lastMessageTime": FieldValue.serverTimestamp(),
                               "userUnread": FieldValue.increment(1),
                               "participants": FieldValue.arrayUnion([user.uid, uid]),
                             }, SetOptions(merge: true));
                             count++;
                           } catch (e) {
                             debugPrint("Error sharing to $chatId: $e");
                           }
                         }
                         if (mounted) {
                           Toaster.show(context, "Meal plan shared with $count client${count > 1 ? 's' : ''}");
                         }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: actionOrange,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16.sh),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.sw)),
                      ),
                      child: Text("Share with ${selectedChatIds.length} Clients", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchClientsForShare(String nutritionistId, {String? requiredBenefit}) async {
    final Map<String, Map<String, dynamic>> clientMap = {};

    // 1. Get all active subscribers
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

      // Filter by benefit if required
      if (requiredBenefit != null && planId != null) {
        bool hasBenefit = false;
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
                return title.contains(requiredBenefit.toLowerCase());
              });
            }
          }
        } catch (e) {
          debugPrint("Error checking benefit $requiredBenefit for plan $planId: $e");
        }
        if (!hasBenefit) continue;
      }

      final chatId = "chat_${userId}_$nutritionistId";
      clientMap[userId] = {
        "userId": userId,
        "chatId": chatId,
      };
    }

    // 2. Get existing chats to include past clients
    final chatsSnap = await FirebaseFirestore.instance
        .collection("chats")
        .where("participants", arrayContains: nutritionistId)
        .get();

    for (var doc in chatsSnap.docs) {
      final data = doc.data();
      final participants = List<String>.from(data["participants"] ?? []);
      final otherUserId = participants.firstWhere((id) => id != nutritionistId, orElse: () => "");
      if (otherUserId.isEmpty) continue;

      if (!clientMap.containsKey(otherUserId)) {
        clientMap[otherUserId] = {
          "userId": otherUserId,
          "chatId": doc.id,
        };
      } else {
        clientMap[otherUserId]!["chatId"] = doc.id;
      }
    }

    // 3. Fetch user details
    final List<Map<String, dynamic>> clients = [];
    for (var entry in clientMap.values) {
      final userId = entry["userId"] as String;
      try {
        final userDoc = await FirebaseFirestore.instance.collection("users").doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          entry["name"] = userData["fullName"] ?? "User";
          entry["photoUrl"] = userData["photoUrl"];
          clients.add(entry); // Only add if user exists
        }
      } catch (e) {
        debugPrint("Error fetching user $userId: $e");
      }
    }
    
    clients.sort((a, b) => (a["name"] as String).compareTo(b["name"] as String));
    return clients;
  }

  void _showRecipeSelectionSheet({Function(String, String, String?)? onSelected}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => RecipeSelectionSheet(
        onRecipeSelected: (recipe) {
          Navigator.pop(context);
          if (onSelected != null) {
            onSelected(recipe['id'], recipe['name'] ?? recipe['title'] ?? 'Recipe', (recipe['recipeImageUrl'] ?? recipe['imageUrl'] ?? recipe['image_url'] ?? recipe['image'] ?? recipe['photoUrl']) as String?);
          } else {
            _showShareRecipePostDialog(recipe);
          }
        },
      ),
    );
  }

  void _showShareRecipePostDialog(Map<String, dynamic> recipe) {
    GlassDialog.show(
      context: context,
      barrierDismissible: false,
      builder: (context) => ShareRecipePostDialog(
        recipe: recipe,
        onPost: (message, tier) async {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) return;

          try {
            await const NutritionistService().shareRecipeAsPost(
              nutritionistId: user.uid,
              recipeId: recipe['id'],
              message: message,
              minTier: tier,
              recipeName: recipe['name'] ?? recipe['title'] ?? 'Recipe',
              recipeImageUrl: (recipe['recipeImageUrl'] ?? recipe['imageUrl'] ?? recipe['image_url'] ?? recipe['image'] ?? recipe['photoUrl']) as String?,
            );

            if (mounted) {
              Toaster.show(context, "Recipe shared successfully!");
            }
          } catch (e) {
            if (mounted) {
              Toaster.show(context, "Failed to share recipe: $e", isError: true);
            }
          }
        },
      ),
    );
  }

  Widget _recentReviewsSection() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Recent Reviews",
          style: TextStyle(
            color: purple,
            fontSize: 22.sp,
            fontWeight: FontWeight.w900,
            fontFamily: "Satoshi",
          ),
        ),
        SizedBox(height: 16.sh),
        StreamBuilder<QuerySnapshot>(
          stream: const NutritionistService().getReviews(uid),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Center(child: Padding(
                padding: EdgeInsets.all(20.sw),
                child: CircularProgressIndicator(color: orange, strokeWidth: 2.sw),
              ));
            }
 
            // Only show up to 5
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) {
              return Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 24.sh),
                decoration: BoxDecoration(
                  color: orange.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(24.sw),
                  border: Border.all(color: orange.withValues(alpha: 0.1), width: 1.sw),
                ),
                child: Column(
                  children: [
                    Icon(Icons.rate_review_outlined, color: orange.withValues(alpha: 0.2), size: 40.sw),
                    SizedBox(height: 12.sh),
                    Text("No reviews yet", style: TextStyle(color: purple.withValues(alpha: 0.4), fontSize: 14.sp, fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }
 
            final displayDocs = docs.take(5).toList();

            return SizedBox(
              height: 200.sh,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(vertical: 8.sh),
                itemCount: displayDocs.length,
                separatorBuilder: (context, _) => SizedBox(width: 16.sw),
                itemBuilder: (context, index) {
                  final data = displayDocs[index].data() as Map<String, dynamic>;
                  return _reviewListItem(data);
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _reviewListItem(Map<String, dynamic> data) {
    final double rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
    final String userName = data['userName'] ?? "Anonymous";
    final String comment = data['reviewText'] ?? "";
    final Timestamp? time = data['timestamp'] as Timestamp?;
    final String userImg = data['userImageUrl'] ?? "";

    return Container(
      width: 320.sw, // Increased width
      padding: EdgeInsets.all(16.sw),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6), // Reverted to original alpha
        borderRadius: BorderRadius.circular(20.sw), // Reverted to original radius
        border: Border.all(color: Colors.white, width: 1), // Reverted to original border
        boxShadow: [
          BoxShadow(color: purple.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)), // Reverted to original shadow
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18.sw,
                backgroundColor: const Color(0xFFF9E3D5),
                child: ClipOval(
                  child: (userImg.isNotEmpty && userImg.startsWith("http"))
                      ? Image.network(
                          userImg,
                          width: 36.sw,
                          height: 36.sw,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(Icons.person, size: 18.sw, color: orange),
                        )
                      : Icon(Icons.person, size: 18.sw, color: orange),
                ),
              ),
              SizedBox(width: 12.sw),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(userName, style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 14.sp)),
                    Row(
                      children: List.generate(5, (i) => Icon(
                        i < rating.floor() ? Icons.star_rounded : Icons.star_border_rounded,
                        color: orange,
                        size: 14.sw,
                      )),
                    ),
                  ],
                ),
              ),
              if (time != null)
                Text(
                  "${time.toDate().day}/${time.toDate().month}",
                  style: TextStyle(color: purple.withValues(alpha: 0.4), fontSize: 11.sp),
                ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            SizedBox(height: 10.sh),
            Text(
              comment,
              style: TextStyle(color: purple.withValues(alpha: 0.8), fontSize: 13.sp, height: 1.4),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _DashboardBackgroundPattern extends StatelessWidget {
  const _DashboardBackgroundPattern();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -100.sh,
            right: -100.sw,
            child: DashFloatingOrb(
              color: const Color(0xFFFFE0D3).withValues(alpha: 0.5),
              size: 400,
              duration: const Duration(seconds: 15),
            ),
          ),
          Positioned(
            bottom: 100.sh,
            left: -150.sw,
            child: DashFloatingOrb(
              color: const Color(0xFFEF8A54).withValues(alpha: 0.1),
              size: 500,
              duration: const Duration(seconds: 20),
            ),
          ),
          Positioned(
            top: 300.sh,
            right: -50.sw,
            child: DashFloatingOrb(
              color: const Color(0xFF7B61FF).withValues(alpha: 0.05),
              size: 300,
              duration: const Duration(seconds: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class DashFloatingOrb extends StatefulWidget {
  final Color color;
  final double size;
  final Duration duration;

  const DashFloatingOrb({required this.color, required this.size, required this.duration});

  @override
  State<DashFloatingOrb> createState() => _DashFloatingOrbState();
}

class _DashFloatingOrbState extends State<DashFloatingOrb> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double angle = _controller.value * 2 * math.pi;
        return Transform.translate(
          offset: Offset(math.cos(angle) * 30, math.sin(angle) * 50),
          child: Container(
            width: widget.size.sw,
            height: widget.size.sw,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [widget.color, widget.color.withValues(alpha: 0)],
              ),
            ),
          ),
        );
      },
    );
  }
}



