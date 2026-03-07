import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

class NutritionistDashboard extends StatefulWidget {
  const NutritionistDashboard({super.key});

  @override
  State<NutritionistDashboard> createState() => _NutritionistDashboardState();
}

class _NutritionistDashboardState extends State<NutritionistDashboard> {
  final Color bg = const Color(0xFFFFF3EB);
  final Color purple = const Color(0xFF462F4D);
  final Color orange = const Color(0xFFEF8A54);
  final Color brown = const Color(0xFF433020);

  int bottomIndex = 0; // 0 dashboard, 1 client, 2 plus, 3 plans, 4 message
  String? fullName;
  String? photoUrl;
  bool loadingProfile = true;
  String saasStatus = "active"; // Default to avoid flashing warning

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

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
          saasStatus = data?['saasStatus'] ?? "unpaid";
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
      {"icon": Icons.medical_services_rounded, "title": "Share Supplement Guide", "subtitle": "Send personalized recommendations", "action": "supplement"},
      {"icon": Icons.add_box_outlined, "title": "Make a Post", "subtitle": "Share health advice, recipes, or updates", "action": "tip"},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF9E3D5),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 50, height: 5,
              decoration: BoxDecoration(color: actionOrange, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                children: [
                  Text(
                    "Quick Actions",
                    style: TextStyle(color: purple, fontSize: 20, fontWeight: FontWeight.w900, fontFamily: "Satoshi"),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...actions.map((a) => _actionItem(a)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: purple,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              fontFamily: "Satoshi",
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionItem(Map<String, dynamic> action) {
    const Color actionOrange = Color(0xFFE48E5B);
    const Color iconColor = Color(0xFF74503C);
    const Color subTextColor = Color(0xFFBFA89A);

    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2EA),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: purple.withValues(alpha:0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            Navigator.pop(context);
            final key = action["action"] as String;
            if (key == "plan") {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const MealPlanCreatorScreen()));
            } else if (key == "tip") {
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted) _showMakePostDialog();
              });
            } else if (key == "supplement") {
              _showSelectClientSheet({}, "supplement_guide", benefitTitle: "Supplement Guide");
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: purple.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: purple.withValues(alpha:0.06)),
                  ),
                  child: Icon(action["icon"] as IconData, color: actionOrange, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action["title"] as String,
                        style: TextStyle(color: purple, fontWeight: FontWeight.w700, fontSize: 15, fontFamily: "Satoshi"),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        action["subtitle"] as String,
                        style: TextStyle(color: subTextColor, fontSize: 12, height: 1.3),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9E3D5),
                    borderRadius: BorderRadius.circular(8),
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
    
    showDialog(
      context: context,
      builder: (context) {
        String? selectedPlanId;
        String? selectedPlanTitle;
        String? selectedRecipeId = initialRecipeId;
        String? selectedRecipeTitle = initialRecipeTitle;
        String? selectedRecipeImageUrl = initialRecipeImageUrl;
        File? attachedImage = initialImage;
        File? attachedDoc = initialDoc;
        bool isPosting = false;
        int selectedTier = 0; // 0: Free, 1: Silver, 2: Gold, 3: Platinum

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
                        initialValue: selectedTier,
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
    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      body: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Container(
          color: bg,
          child: Stack(
            children: [
              const _DashboardBackgroundPattern(),
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
    );
  }

  Widget _topRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: _openSettings,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: Container(
                width: 50,
                height: 50,
                color: const Color(0xFFD9D9D9),
                child: photoUrl != null && photoUrl!.startsWith("http")
                    ? Image.network(photoUrl!, fit: BoxFit.cover)
                    : Image.asset("assets/Logos/mainLogo.png", fit: BoxFit.cover),
              ),
            ),
          ),
          const Spacer(),
          // View Switcher Button (Restaurant Icon)
          GestureDetector(
            onTap: _switchToUserView,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9E3D5),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: purple.withValues(alpha:0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Icon(Icons.restaurant_rounded, color: orange, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashboardHome() {
    final bool isSaaSInactive = saasStatus != "active";

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      children: [
        if (isSaaSInactive && !loadingProfile) ...[
          const SizedBox(height: 12),
          _saasWarningBanner(),
        ],
        const SizedBox(height: 20),
        Text(
          "Welcome,",
          style: TextStyle(
            color: purple,
            fontSize: 24,
            fontWeight: FontWeight.w500,
            fontFamily: "Satoshi",
          ),
        ),
        Text(
          loadingProfile ? "..." : (fullName ?? "Nutritionist"),
          style: TextStyle(
            color: purple,
            fontSize: 40,
            fontWeight: FontWeight.w900,
            height: 1.1,
            fontFamily: "Satoshi",
          ),
        ),
        const SizedBox(height: 32),
        _statsGrid(),
        const SizedBox(height: 32),
        _subscriptionTiersSection(),
        const SizedBox(height: 32),
        _upcomingAppointments(),
        const SizedBox(height: 32),
        _clientInsights(),
        const SizedBox(height: 120), // Spacing for bottom nav
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
                  // Count unique original users to avoid duplicates if they changed plans
                  final Set<String> uniqueUsers = {};
                  if (snap.hasData) {
                    for (var d in snap.data!.docs) {
                      final data = d.data() as Map<String, dynamic>;
                      final uid = data["userId"];
                      if (uid != null) uniqueUsers.add(uid);
                    }
                  }
                  return _statCard("Active Clients", uniqueUsers.length.toString(), Icons.people_rounded);
                }
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("nutritionists")
                    .doc(uid)
                    .collection("subscription_plans")
                    .snapshots(),
                builder: (context, snap) {
                  final count = snap.data?.docs.length ?? 0;
                  return _statCard("Total Plans", count.toString(), Icons.restaurant_menu_rounded);
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
                if (subSnap.hasData && subSnap.data != null) {
                  // Track highest price per user to handle transitions accurately
                  final Map<String, double> userPayments = {};
                  for (var doc in subSnap.data!.docs) {
                    final d = doc.data() as Map<String, dynamic>;
                    final userId = d["userId"];
                    final price = (d["price"] ?? 0).toDouble();
                    if (userId != null) {
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
                            child: _statCard(
                              "Total Earnings", 
                              loading ? "..." : "Rs. ${total.toInt()}", 
                              Icons.monetization_on_rounded,
                              // subtitle: "View History",
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                         Expanded(
                          child: _statCard(
                            "Projected/Mo", 
                            "Rs. ${projectedMonthly.toInt()}", 
                            Icons.trending_up_rounded,
                            subtitle: "Based on active subs",
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: orange.withValues(alpha:0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: orange.withValues(alpha:0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: orange, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Direct Payments Active",
                                    style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    "Client payments are processed directly to your Stripe account.",
                                    style: TextStyle(color: purple.withValues(alpha:0.6), fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, {String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(16), // Reduced padding to prevent overflow
      decoration: BoxDecoration(
        color: const Color(0xFFF9E3D5), // Updated to requested color
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: purple.withValues(alpha:0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF2EA), // Updated to requested color
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: orange, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: purple,
                  fontSize: 20, // Slightly reduced to prevent overflow
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
                  fontSize: 11, // Slightly reduced to prevent overflow
                  fontWeight: FontWeight.w500,
                  fontFamily: "Satoshi",
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: orange,
                    fontSize: 9,
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
                fontSize: 22,
                fontWeight: FontWeight.w900,
                fontFamily: "Satoshi",
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
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
                    padding: const EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: orange, strokeWidth: 2),
                  ));
                }

                final meetings = meetingSnap.data ?? [];
                if (meetings.isEmpty) {
                  return _emptyScheduleCard();
                }

                // Show up to 3 upcoming
                final display = meetings.take(3).toList();

                return Column(
                  children: display.map((m) => _sessionCard(m)).toList(),
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
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: orange.withValues(alpha:0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: orange.withValues(alpha:0.1), width: 1),
      ),
      child: Column(
        children: [
          Icon(Icons.calendar_month_rounded, color: orange.withValues(alpha:0.3), size: 40),
          const SizedBox(height: 12),
          Text(
            "No upcoming sessions",
            style: TextStyle(
              color: purple.withValues(alpha:0.4),
              fontSize: 14,
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: purple.withValues(alpha:0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          // Date badge
          Container(
            width: 54,
            height: 60,
            decoration: BoxDecoration(
              color: isToday ? orange : orange.withValues(alpha:0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  date.day.toString(),
                  style: TextStyle(
                    color: isToday ? Colors.white : orange,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Satoshi",
                  ),
                ),
                Text(
                  _monthName(date.month).substring(0, 3).toUpperCase(),
                  style: TextStyle(
                    color: isToday ? Colors.white.withValues(alpha:0.8) : orange.withValues(alpha:0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Consultation with $clientName",
                  style: TextStyle(color: purple, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: "Satoshi"),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 14, color: orange),
                    const SizedBox(width: 4),
                    Text(
                      "$dateLabel • $time",
                      style: TextStyle(color: purple.withValues(alpha:0.5), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    notes,
                    style: TextStyle(color: purple.withValues(alpha:0.4), fontSize: 11, fontStyle: FontStyle.italic),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          // Status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isToday ? orange.withValues(alpha:0.1) : purple.withValues(alpha:0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isToday ? "Today" : (isTomorrow ? "Tomorrow" : "Upcoming"),
              style: TextStyle(
                color: isToday ? orange : purple.withValues(alpha:0.5),
                fontSize: 10,
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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [purple, const Color(0xFF63456D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                "Subscriber Analytics",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: "Satoshi",
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("subscriptions")
                .where("nutritionistId", isEqualTo: user?.uid)
                .where("status", whereIn: ["active", "trialing"])
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Text(
                  "Analytics will appear here once you have active subscribers.",
                  style: TextStyle(color: Colors.white.withValues(alpha:0.6), fontSize: 13, height: 1.4),
                );
              }

              // Calculate distributions — keep only the HIGHEST tier per user
              final Map<String, int> userTier = {};
              final Map<String, double> userPrice = {};

              for (var doc in snapshot.data!.docs) {
                final d = doc.data() as Map<String, dynamic>;
                final uid = d["userId"];
                if (uid == null) continue;

                int tier = 0;
                final rawTier = d["tierLevel"];
                if (rawTier is num) tier = rawTier.toInt();
                else if (rawTier is String) tier = int.tryParse(rawTier) ?? 0;

                final double price = (d["price"] ?? 0).toDouble();

                // Only keep the highest tier per user
                if (!userTier.containsKey(uid) || tier > userTier[uid]!) {
                  userTier[uid] = tier;
                  userPrice[uid] = price;
                }
              }

              // Aggregate by tier
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

              double maxRev = tierRevenue.values.fold(1, (a, b) => a > b ? a : b);

              return Column(
                children: [
                   const SizedBox(height: 10),
                   // Bar Chart
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                     crossAxisAlignment: CrossAxisAlignment.end,
                     children: [
                       _tierBar("Silver", tierRevenue[1]!, tierCounts[1]!, const Color(0xFF708090), maxRev),
                       _tierBar("Gold", tierRevenue[2]!, tierCounts[2]!, const Color(0xFFDAA520), maxRev),
                       _tierBar("Platinum", tierRevenue[3]!, tierCounts[3]!, const Color(0xFF4B0082), maxRev),
                     ],
                   ),
                   const SizedBox(height: 24),
                   Container(
                     padding: const EdgeInsets.all(16),
                     decoration: BoxDecoration(
                       color: Colors.white.withValues(alpha:0.08),
                       borderRadius: BorderRadius.circular(20),
                     ),
                     child: Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         _summaryItem("Clients", totalClients.toString()),
                         _summaryItem("Avg/Sub", "Rs. ${(totalClients == 0 ? 0 : tierRevenue.values.fold(0.0, (a,b)=>a+b) / totalClients).toInt()}"),
                         _summaryItem("Stability", "98%"),
                       ],
                     ),
                   )
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _tierBar(String label, double revenue, int count, Color color, double maxRev) {
    double heightFactor = revenue / maxRev;
    if (heightFactor < 0.1 && revenue > 0) heightFactor = 0.1;
    
    return Column(
      children: [
        Text("Rs. ${revenue.toInt()}", style: TextStyle(color: Colors.white.withValues(alpha:0.6), fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          width: 45,
          height: 100 * heightFactor,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: color.withValues(alpha:0.3), blurRadius: 8, offset: const Offset(0, 4))],
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        Text("$count subs", style: TextStyle(color: Colors.white.withValues(alpha:0.4), fontSize: 9)),
      ],
    );
  }

  Widget _summaryItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha:0.5), fontSize: 10, fontWeight: FontWeight.bold)),
      ],
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
            Text(
              "Subscription Plans",
              style: TextStyle(
                color: purple,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                fontFamily: "Satoshi",
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => bottomIndex = 3),
              child: Text(
                "Manage",
                style: TextStyle(
                  color: orange,
                  fontSize: 14,
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF9E3D5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF2EA),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(Icons.star_rounded, color: orange, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  "Rs. $price",
                  style: TextStyle(color: orange, fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF462F4D)),
        ],
      ),
    );
  }

  Widget _emptyHubCard([String? uid]) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: orange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: orange.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Icon(Icons.add_circle_outline_rounded, color: orange.withValues(alpha: 0.3), size: 40),
          const SizedBox(height: 12),
          Text(
            "No plans published yet",
            style: TextStyle(
              color: purple.withValues(alpha: 0.4),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (uid != null) ...[
            const SizedBox(height: 4),
            Text(
              "UID: $uid",
              style: TextStyle(color: purple.withValues(alpha: 0.2), fontSize: 9),
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

  

  Widget _saasWarningBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: orange.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: orange.withValues(alpha:0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: orange, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Platform Membership Inactive",
                  style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Your profile is currently hidden from users. Pay the monthly fee to activate your listing.",
            style: TextStyle(color: purple.withValues(alpha:0.6), fontSize: 12),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PayoutManagementScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text("Resolve Now", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  void _showSavedPlansSheet() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    const Color actionOrange = Color(0xFFE48E5B);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Color(0xFFFFF3EB),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 20),
              width: 50, height: 5,
              decoration: BoxDecoration(color: actionOrange, borderRadius: BorderRadius.circular(3)),
            ),
            Text("Your Saved Meal Plans", style: TextStyle(color: purple, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("nutritionists")
                    .doc(user.uid)
                    .collection("meal_plans")
                    .orderBy("updatedAt", descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return const Center(child: Text("Error loading plans"));
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: actionOrange));
                  
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) return const Center(child: Text("No saved plans found. Create one first!"));

                  return ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final id = docs[index].id;
                      final title = data["title"] ?? "Untitled Plan";
                      final days = data["duration"] ?? 0;
                      final cals = data["targetCalories"] ?? 0;

                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(context); // Close sheet
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MealPlanCreatorScreen(
                                existingPlanId: id,
                                initialData: data,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: purple.withValues(alpha:0.05), blurRadius: 4, offset: const Offset(0, 2))],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: actionOrange.withValues(alpha:0.1), borderRadius: BorderRadius.circular(12)),
                                child: const Icon(Icons.restaurant_menu_rounded, color: actionOrange),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title, style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text("$days Days • ~ $cals kcal", style: TextStyle(color: purple.withValues(alpha:0.6), fontSize: 13)),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.share_rounded, color: actionOrange, size: 20),
                                    onPressed: () {
                                      Navigator.pop(context); // Close sheet
                                      _showSelectClientSheet(data, id);
                                    },
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(8),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.edit_rounded, color: actionOrange, size: 20),
                                    onPressed: () {
                                      Navigator.pop(context); // Close sheet
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => MealPlanCreatorScreen(
                                            existingPlanId: id,
                                            initialData: data,
                                          ),
                                        ),
                                      );
                                    },
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(8),
                                  ),
                                ],
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
          ],
        ),
      ),
    );
  }

  void _showSelectClientSheet(Map<String, dynamic> planData, String planId, {String? benefitTitle}) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    const Color actionOrange = Color(0xFFE48E5B);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Color(0xFFFFF3EB),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 20),
              width: 50, height: 5,
              decoration: BoxDecoration(color: actionOrange, borderRadius: BorderRadius.circular(3)),
            ),
            Text(
              benefitTitle != null ? "Share $benefitTitle" : "Select Client to Share With",
              style: TextStyle(color: purple, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchClientsForShare(user.uid, requiredBenefit: benefitTitle ?? "InChat meal plans"),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: actionOrange));
                  }
                  if (snapshot.hasError) {
                    return const Center(child: Text("Error loading clients"));
                  }

                  final clients = snapshot.data ?? [];
                  if (clients.isEmpty) return const Center(child: Text("No clients found."));

                  return ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: clients.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
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
                                 "type": "meal_plan",
                                 "planData": {...planData, "planId": planId},
                                 "timestamp": FieldValue.serverTimestamp(),
                                 "read": false,
                               });
                             
                             await FirebaseFirestore.instance.collection("chats").doc(chatId).set({
                               "lastMessage": "Shared a meal plan: ${planData['title'] ?? 'Untitled'}",
                               "lastMessageTime": FieldValue.serverTimestamp(),
                               "userUnread": FieldValue.increment(1),
                               "nutritionistUnread": 0,
                               // Make sure participants array exists in case this is a brand new chat
                               "participants": FieldValue.arrayUnion([user.uid, otherUserId]),
                             }, SetOptions(merge: true));

                             if (context.mounted) {
                               Navigator.pop(context); // Close client selection
                               Toaster.show(context, planId == "supplement_guide" ? "Supplement request sent to $otherUserName" : "Meal plan sent to $otherUserName");
                             }
                           } catch (e) {
                             if (context.mounted) {
                               Toaster.show(context, "Error sharing meal plan: $e", isError: true);
                             }
                           }
                        },
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: purple.withValues(alpha:0.05)),
                        ),
                        tileColor: Colors.white,
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: purple.withValues(alpha:0.1),
                          backgroundImage: otherUserPhoto != null ? NetworkImage(otherUserPhoto) : null,
                          child: otherUserPhoto == null ? Icon(Icons.person, color: purple) : null,
                        ),
                        title: Text(otherUserName, style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 16)),
                        trailing: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: actionOrange.withValues(alpha:0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.send_rounded, color: actionOrange, size: 20),
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
    showDialog(
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
}

class _DashboardBackgroundPattern extends StatelessWidget {
  const _DashboardBackgroundPattern();

  @override
  Widget build(BuildContext context) {
    const baseW = 393.0;
    const baseH = 852.0;
    final size = MediaQuery.of(context).size;
    double sx(double v) => v * (size.width / baseW);
    double sy(double v) => v * (size.height / baseH);
    final stroke = const Color(0xFFF5DDCE);

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: sx(-154),
            top: sy(-14),
            child: Transform.rotate(
              angle: 21 * math.pi / 180,
              child: Container(
                width: sx(271),
                height: sy(159),
                decoration: BoxDecoration(
                  border: Border.all(color: stroke),
                  borderRadius: BorderRadius.all(
                    Radius.elliptical(sx(136), sy(80)),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: sx(-149),
            top: sy(-100),
            child: Transform.rotate(
              angle: 4 * math.pi / 180,
              child: Container(
                width: sx(303),
                height: sy(329),
                decoration: BoxDecoration(
                  border: Border.all(color: stroke),
                  borderRadius: BorderRadius.all(
                    Radius.elliptical(sx(152), sy(165)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}



