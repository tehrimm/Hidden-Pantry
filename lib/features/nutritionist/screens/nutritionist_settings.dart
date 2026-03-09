import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/features/onboarding/screens/loading_five.dart';
import 'package:hidden_pantry_app/features/recipes/screens/my_recipes.dart';
import 'package:hidden_pantry_app/features/nutritionist/services/nutritionist_service.dart';
import 'package:hidden_pantry_app/features/nutritionist/screens/payout_management.dart';
import 'package:hidden_pantry_app/features/nutritionist/screens/nutritionist_meal_plans_screen.dart';

import 'package:hidden_pantry_app/features/nutritionist/screens/nutritionist_profile_setting.dart';
import 'package:hidden_pantry_app/core/services/notification_service.dart';
import 'package:hidden_pantry_app/features/user/models/notification_model.dart';
import 'package:hidden_pantry_app/features/user/screens/notifications_screen.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';
import 'package:hidden_pantry_app/features/nutritionist/screens/help_support.dart';
import 'package:hidden_pantry_app/features/user/screens/my_favourites.dart';
import 'package:hidden_pantry_app/features/user/screens/user_network_screen.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';

class NutritionistSettingsScreen extends StatefulWidget {
  const NutritionistSettingsScreen({super.key});

  @override
  State<NutritionistSettingsScreen> createState() => _NutritionistSettingsScreenState();
}

class _NutritionistSettingsScreenState extends State<NutritionistSettingsScreen> {
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
          name = data?["fullName"] ?? user.displayName ?? "Nutritionist";
          email = data?["email"] ?? user.email ?? "";
          photoUrl = data?["photoUrl"] ?? user.photoURL;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          name = user.displayName ?? "Nutritionist";
          email = user.email ?? "";
          photoUrl = user.photoURL;
          loading = false;
        });
      }
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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No user logged in');
      const nutritionistService = NutritionistService();
      await nutritionistService.deleteNutritionist(user.uid);
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deleted successfully.')),
      );
      
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

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    final topPad = MediaQuery.of(context).padding.top;
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: ClipRRect(
        borderRadius: BorderRadius.circular(30.sw),
        child: Container(
          color: bg,
          child: Stack(
            children: [
              const _SettingsBackgroundPattern(), // Fixed Pattern

              // Scrollable Content
              SafeArea(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        children: [
                          SizedBox(height: 96.sh), // Space for Fixed Header
                          Expanded(
                            child: SingleChildScrollView(
                              padding: EdgeInsets.symmetric(horizontal: 22.sw, vertical: 20.sh),
                              child: Column(
                                children: [
                                  // Profile Block
                                  _profileBlock(),
                                  SizedBox(height: 30.sh),
                                  
                                  // Tiles
                                  _tile(
                                    icon: "assets/icons/setting.png",
                                    title: "Profile Setting",
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const NutritionistProfileSettingScreen()),
                                      ).then((_) => _loadProfile());
                                    },
                                  ),
                                  _tile(
                                    iconData: Icons.restaurant_menu_rounded,
                                    title: "Create Meal Plans",
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const NutritionistMealPlansScreen()),
                                      );
                                    },
                                  ),
                                  _tile(
                                    icon: "assets/icons/card.png",
                                    title: "Payouts & Earnings",
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const PayoutManagementScreen()),
                                      );
                                    },
                                  ),

                                  _tile(
                                    icon: "assets/icons/book.png",
                                    title: "My Recipes",
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const MyRecipesScreen()),
                                      );
                                    },
                                  ),
                                  _tile(
                                    iconData: Icons.favorite_border_rounded,
                                    title: "My Favourites",
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const MyFavouritesScreen(isNutritionist: true)),
                                      );
                                    },
                                  ),
                                  _tile(
                                    icon: "assets/icons/users.png",
                                    title: "My Network",
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const UserNetworkScreen(isNutritionist: true)),
                                      );
                                    },
                                  ),
                                  StreamBuilder<List<AppNotification>>(
                                    stream: NotificationService().streamNotifications(),
                                    builder: (context, snapshot) {
                                      final unreadCount = snapshot.data?.where((n) => !n.isRead).length ?? 0;
                                      return _tile(
                                        icon: "assets/icons/notification.png",
                                        title: "Notifications",
                                        trailingIcon: unreadCount > 0 
                                          ? Container(
                                              padding: EdgeInsets.symmetric(horizontal: 8.sw, vertical: 4.sh),
                                              decoration: BoxDecoration(color: orange, borderRadius: BorderRadius.circular(10.sw)),
                                              child: Text(
                                                unreadCount > 9 ? "9+" : "$unreadCount",
                                                style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.bold),
                                              ),
                                            )
                                          : null,
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (_) => const NotificationsScreen(isNutritionist: true)),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                  _tile(
                                    icon: "assets/icons/question.png",
                                    title: "Help & Support",
                                    onTap: () {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen()));
                                    },
                                  ),
                                  SizedBox(height: 26.sh),
                                  _logoutButton(),
                                  SizedBox(height: 16.sh),
                                  _deleteAccountButton(),
                                  SizedBox(height: 100.sh), // Bottom padding
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
              ),

              // Fixed Header
              Positioned(
                top: topPad + 36.sh,
                left: 22.sw,
                right: 22.sw,
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 50.sw,
                        height: 50.sw,
                        decoration: BoxDecoration(
                          color: tileBg,
                          borderRadius: BorderRadius.circular(25.sw),
                        ),
                        child: Center(
                          child: Icon(Icons.arrow_back_ios_new_rounded, size: 18.sw, color: brown),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      "Settings",
                      style: TextStyle(
                        color: purple,
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                        fontFamily: "Satoshi",
                      ),
                    ),
                    const Spacer(flex: 2),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileBlock() {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(30.sw),
          child: Container(
            width: 60.sw,
            height: 60.sw,
            color: const Color(0xFFD9D9D9),
            child: photoUrl != null && photoUrl!.startsWith("http")
                ? Image.network(photoUrl!, fit: BoxFit.cover)
                : Image.asset("assets/logos/main_logo.png", fit: BoxFit.cover),
          ),
        ),
        SizedBox(width: 16.sw),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loading ? "..." : (name ?? "Nutritionist"),
                style: TextStyle(
                  color: purple,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  fontFamily: "Satoshi",
                ),
              ),
              Text(
                loading ? "" : (email ?? ""),
                style: TextStyle(
                  color: purple.withValues(alpha: 0.55),
                  fontSize: 15.sp,
                  fontFamily: "Satoshi",
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tile({
    String? icon,
    IconData? iconData,
    required String title,
    required VoidCallback onTap,
    Widget? trailingIcon,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.sh),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 70.sh,
          decoration: BoxDecoration(
            color: tileBg,
            borderRadius: BorderRadius.circular(20.sw),
          ),
          child: Row(
            children: [
              SizedBox(width: 20.sw),
              if (icon != null)
                Image.asset(icon, width: 18.sw, height: 18.sw, fit: BoxFit.contain)
              else if (iconData != null)
                Icon(iconData, color: purple, size: 20.sw),
              SizedBox(width: 16.sw),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: purple,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    fontFamily: "Satoshi",
                  ),
                ),
              ),
              if (trailingIcon != null) ...[
                trailingIcon,
                SizedBox(width: 12.sw),
              ],
              Image.asset("assets/icons/next_brown.png", width: 18.sw, height: 14.sh, fit: BoxFit.contain),
              SizedBox(width: 20.sw),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoadingFive()),
    );
  }

  Widget _logoutButton() {
    return GestureDetector(
      onTap: _logout,
      child: Container(
        height: 70.sh,
        decoration: BoxDecoration(
          color: orange,
          borderRadius: BorderRadius.circular(20.sw),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset("assets/icons/logout.png", width: 18.sw, height: 18.sw, fit: BoxFit.contain),
            SizedBox(width: 12.sw),
            Text(
              "Logout",
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                fontFamily: "Satoshi",
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deleteAccountButton() {
    return GestureDetector(
      onTap: loading ? null : _deleteAccount,
      child: Container(
        height: 70.sh,
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(20.sw),
        ),
        child: Center(
          child: Text(
            "Delete Account",
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              fontFamily: "Satoshi",
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsBackgroundPattern extends StatelessWidget {
  const _SettingsBackgroundPattern();

  @override
  Widget build(BuildContext context) {
    const stroke = Color(0xFFF5DDCE);

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: (-154).sw,
            top: (-14).sh,
            child: Transform.rotate(
              angle: 21 * math.pi / 180,
              child: Container(
                width: 271.sw,
                height: 159.sh,
                decoration: BoxDecoration(
                  border: Border.all(color: stroke),
                  borderRadius: BorderRadius.all(
                    Radius.elliptical(136.sw, 80.sh),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: (-149).sw,
            top: (-100).sh,
            child: Transform.rotate(
              angle: 4 * math.pi / 180,
              child: Container(
                width: 303.sw,
                height: 329.sh,
                decoration: BoxDecoration(
                  border: Border.all(color: stroke),
                  borderRadius: BorderRadius.all(
                    Radius.elliptical(152.sw, 165.sh),
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
