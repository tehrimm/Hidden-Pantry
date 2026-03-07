import 'package:hidden_pantry_app/features/user/screens/my_plans.dart';
import 'package:hidden_pantry_app/features/user/screens/my_subscriptions.dart';
import 'package:hidden_pantry_app/features/user/screens/my_favourites.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/features/user/screens/notifications_screen.dart';

import 'package:hidden_pantry_app/features/onboarding/screens/loading_five.dart';
import 'profile_setting.dart';
import 'package:hidden_pantry_app/features/recipes/screens/my_recipes.dart';
// import 'notifications.dart'; // Removed duplicate
import 'package:hidden_pantry_app/features/admin/screens/admin_certificate_review.dart';
import 'package:hidden_pantry_app/features/user/services/user_service.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:hidden_pantry_app/core/widgets/main_navigation_shell.dart';
import 'package:hidden_pantry_app/features/user/screens/user_network_screen.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final Color bg = const Color(0xFFFFF3EB);
  final Color purple = const Color(0xFF462F4D);
  final Color brown = const Color(0xFF433020);
  final Color tileBg = const Color(0xFFF9E3D5);
  final Color orange = const Color(0xFFEF8A54);


  String? name;
  String? email;
  String? photoUrl;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  bool _hasError = false;

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      _hasError = false;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          name = "Guest";
          email = "";
          photoUrl = null;
          loading = false;
        });
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 10));

      final data = doc.data();

      if (mounted) {
        setState(() {
          // correct field name
          name = (data?["fullName"] as String?)?.trim().isNotEmpty == true
              ? (data?["fullName"] as String).trim()
              : (user.displayName?.trim().isNotEmpty == true
                  ? user.displayName!.trim()
                  : "Hidden Pantry");

          email = (data?["email"] as String?)?.trim().isNotEmpty == true
              ? (data?["email"] as String).trim()
              : (user.email ?? "");

          photoUrl = (data?["photoUrl"] as String?)?.trim().isNotEmpty == true
              ? (data?["photoUrl"] as String).trim()
              : (user.photoURL);

          loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
      if (mounted) {
        setState(() {
          loading = false;
          _hasError = true;
          // Keep existing values or defaults if this is the first load
          name ??= user.displayName ?? "Hidden Pantry";
          email ??= user.email ?? "";
          photoUrl ??= user.photoURL;
        });
      }
    }
  }


  void _go(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen))
        .then((_) => _loadProfile()); // refresh when returning
  }

  Future<void> _logout() async {
    // Navigate immediately without waiting for signOut — prevents hanging
    // in test environments where MethodChannel may not respond.
    // signOut still runs in the background and clears the auth session.
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoadingFive()),
    );
    try {
      await FirebaseAuth.instance.signOut()
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('[UserProfileScreen] signOut error: $e');
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to permanently delete your account? This action cannot be undone and all your data will be lost.',
          style: TextStyle(fontFamily: 'Satoshi'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: purple)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => loading = true);

    try {
      final userService = UserService();
      await userService.deleteUserAccount();
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      Toaster.show(context, 'Account deleted successfully.');
      
      // Redirect to starting screen and clear stack
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoadingFive()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      
      String errorMsg = 'Error deleting account.';
      if (e.toString().contains('requires-recent-login')) {
        errorMsg = 'This action requires a recent login. Please sign out and sign in again before deleting.';
      }
      
      Toaster.show(context, errorMsg, isError: true);
      debugPrint("Account deletion failed: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget _deleteAccountButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: GestureDetector(
        onTap: loading ? null : _deleteAccount,
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Center(
            child: Text(
              "Delete Account",
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
                fontFamily: "Satoshi",
              ),
            ),
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final double topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: bg,
      body: Container(
        color: bg,
        child: Stack(
          children: [
            const PatternBackground(),

            // Content Area (Scrollable below header)
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 80), // Absolute gap for fixed header
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 120),
                      children: [
                        // Profile block
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _avatar(),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_hasError) ...[
                                      Text(
                                        "Error loading profile",
                                        style: TextStyle(
                                          color: Colors.red[700],
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: "Satoshi",
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      GestureDetector(
                                        onTap: _loadProfile,
                                        child: Text(
                                          "Tap to Retry",
                                          style: TextStyle(
                                            color: purple,
                                            fontSize: 14,
                                            decoration: TextDecoration.underline,
                                            fontFamily: "Satoshi",
                                          ),
                                        ),
                                      ),
                                    ] else ...[
                                      Text(
                                        loading ? "..." : (name ?? "Hidden Pantry"),
                                        style: TextStyle(
                                          color: purple,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: "Satoshi",
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Opacity(
                                        opacity: 0.55,
                                        child: Text(
                                          loading ? "" : (email ?? ""),
                                          style: TextStyle(
                                            color: purple,
                                            fontSize: 15,
                                            fontFamily: "Satoshi",
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Buttons
                        _tile(
                          icon: "assets/icons/setting.png",
                          title: "Profile Setting",
                          onTap: () => _go(const ProfileSettingScreen()),
                        ),
                        _tile(
                          icon: "assets/icons/book.png",
                          title: "My Recipes",
                          onTap: () => _go(const MyRecipesScreen()),
                        ),
                        // New Favourites Tile
                        _tile(
                          iconData: Icons.favorite_border_rounded, 
                          title: "My Favourites", 
                          onTap: () => _go(const MyFavouritesScreen()),
                        ),
                        _tile(
                          iconData: Icons.restaurant_menu_rounded, 
                          title: "Meal Plans",
                          onTap: () => _go(const MyPlansScreen()),
                        ),
                        _tile(
                          icon: "assets/icons/card.png", // Using card as placeholder for subs
                          title: "My Subscriptions",
                          onTap: () => _go(const MySubscriptionsScreen()),
                        ),
                        _tile(
                          icon: "assets/icons/notification.png",
                          title: "Notification",
                          onTap: () => _go(const NotificationsScreen()),
                        ),
                        _tile(
                          icon: "assets/icons/users.png", // Using existing icon
                          title: "My Network",
                          onTap: () => _go(const UserNetworkScreen()),
                        ),
                        
                        // Admin button (conditional)
                        if (email == "hiddenpantry50@gmail.com")
                          _tile(
                            icon: "assets/icons/setting.png",
                            title: "Certificates Pending Approval",
                            onTap: () => _go(const AdminCertificateReviewScreen()),
                          ),

                        const SizedBox(height: 26),

                        // Logout button
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          child: GestureDetector(
                            onTap: _logout,
                            child: Container(
                              height: 70,
                              decoration: BoxDecoration(
                                color: orange,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    "assets/icons/logout.png",
                                    width: 18,
                                    height: 18,
                                    fit: BoxFit.contain,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    "Logout",
                                    style: TextStyle(
                                      color: const Color(0xFFFFF2EA),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                      fontFamily: "Satoshi",
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _deleteAccountButton(),
                        const SizedBox(height: 100), // Prevent cutoff
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Fixed Header (Top Layer)
            Positioned(
              left: 30,
              top: topPad + 20,
              child: BackButtonWidget(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => MainNavigationShell()),
                    (route) => false,
                  );
                },
                color: brown,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: topPad + 20,
              height: 50,
              child: Center(
                child: Text(
                  "My profile",
                  style: TextStyle(
                    color: purple,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: "Satoshi",
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }




  Widget _avatar() {
    final hasNet = photoUrl != null && photoUrl!.trim().isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 60,
        height: 60,
        color: const Color(0xFFD9D9D9),
        child: hasNet
            ? Image.network(
                photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Image.asset(
                    "assets/Logos/profile_placeholder.png",
                    width: 21,
                    height: 21,
                    fit: BoxFit.contain,
                  ),
                ),
              )
            : Center(
                child: Image.asset(
                  "assets/Logos/profile_placeholder.png",
                  width: 21,
                  height: 21,
                  fit: BoxFit.contain,
                ),
              ),
      ),
    );
  }

  Widget _tile({
    String? icon,
    IconData? iconData,
    required String title,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: tileBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const SizedBox(width: 20),
              if (icon != null)
                Image.asset(icon, width: 18, height: 18, fit: BoxFit.contain)
              else if (iconData != null)
                Icon(iconData, color: purple, size: 20),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: purple,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                    fontFamily: "Satoshi",
                  ),
                ),
              ),
              Image.asset(
                "assets/icons/next_brown.png",
                width: 18,
                height: 14,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 20),
            ],
          ),
        ),
      ),
    );
  }
}

