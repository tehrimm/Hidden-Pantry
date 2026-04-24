import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hidden_pantry_app/core/utils/glass_dialog.dart';
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
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:hidden_pantry_app/features/user/screens/my_subscriptions.dart';
import 'package:hidden_pantry_app/features/user/screens/my_plans.dart';

class NutritionistSettingsScreen extends StatefulWidget {
  const NutritionistSettingsScreen({super.key});

  @override
  State<NutritionistSettingsScreen> createState() => _NutritionistSettingsScreenState();
}

class _NutritionistSettingsScreenState extends State<NutritionistSettingsScreen> {
  final Color bg = const Color(0xFFFFF7F2);
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

  void _go(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen))
        .then((_) => _loadProfile());
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoadingFive()),
    );
  }

  Future<void> _deleteAccount() async {
    final confirmed = await GlassDialog.show<bool>(
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
    final double topPad = MediaQuery.of(context).padding.top;
    
    return Scaffold(
      backgroundColor: bg,
      body: Container(
        color: bg,
        child: Stack(
          children: [
            const PatternBackground(),

            // Content Area
            SafeArea(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        SizedBox(height: 96.sh), // Absolute gap for fixed header
                        Expanded(
                          child: ListView(
                            padding: EdgeInsets.only(bottom: 20.sh),
                            children: [
                              // Profile block
                              _modernProfileHeader(),
                              SizedBox(height: 20.sh),
                              
                              // Tiles
                              _tile(
                                icon: "assets/icons/setting.png",
                                title: "Profile Setting",
                                onTap: () => _go(const NutritionistProfileSettingScreen()),
                              ),
                                _tile(
                                  iconData: Icons.restaurant_menu_rounded,
                                  title: "Create Meal Plans",
                                  onTap: () => _go(const NutritionistMealPlansScreen()),
                                ),
                                _tile(
                                  iconData: Icons.shopping_bag_outlined,
                                  title: "Purchased Plans",
                                  onTap: () => _go(const MyPlansScreen()),
                                ),
                                _tile(
                                  icon: "assets/icons/card.png",
                                  title: "My Subscriptions",
                                  onTap: () => _go(const MySubscriptionsScreen()),
                                ),
                                _tile(
                                  iconData: Icons.payments_rounded,
                                  title: "Payouts & Earnings",
                                  onTap: () => _go(const PayoutManagementScreen()),
                                ),
                              _tile(
                                icon: "assets/icons/book.png",
                                title: "My Recipes",
                                onTap: () => _go(const MyRecipesScreen()),
                              ),
                              _tile(
                                iconData: Icons.favorite_border_rounded,
                                title: "My Favourites",
                                onTap: () => _go(const MyFavouritesScreen(isNutritionist: true)),
                              ),
                              _tile(
                                icon: "assets/icons/users.png",
                                title: "My Network",
                                onTap: () => _go(const UserNetworkScreen(isNutritionist: true)),
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
                                    onTap: () => _go(const NotificationsScreen(isNutritionist: true)),
                                  );
                                },
                              ),
                              _tile(
                                iconData: Icons.help_outline_rounded,
                                title: "Help & Support",
                                onTap: () => _go(const HelpSupportScreen()),
                              ),

                              SizedBox(height: 26.sh),

                              // Logout button
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 22.sw),
                                child: GestureDetector(
                                  onTap: () {
                                     HapticFeedback.lightImpact();
                                     _logout();
                                  },
                                  child: Container(
                                    height: 70.sh,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [orange, const Color(0xFFFFA06A)],
                                      ),
                                      borderRadius: BorderRadius.circular(22.sw),
                                      boxShadow: [
                                        BoxShadow(
                                          color: orange.withValues(alpha: 0.3),
                                          blurRadius: 12,
                                          offset: const Offset(0, 6),
                                        )
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Image.asset(
                                          "assets/icons/logout.png",
                                          width: 18.sw,
                                          height: 18.sh,
                                          fit: BoxFit.contain,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 12.sw),
                                        Text(
                                          "Logout",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 15.sp,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.2,
                                            fontFamily: "Satoshi",
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 16.sh),
                              _deleteAccountButton(),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),

            // Fixed Header (Top Layer)
            Positioned(
              left: 30.sw,
              top: topPad + 36.sh,
              child: BackButtonWidget(
                onPressed: () => Navigator.pop(context),
                color: brown,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: topPad + 36.sh,
              height: 50.sh,
              child: Center(
                child: Text(
                  "Settings",
                  style: TextStyle(
                    color: purple,
                    fontSize: 26.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
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

  Widget _modernProfileHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 22.sw),
      child: Container(
        padding: EdgeInsets.all(16.sw),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(24.sw),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                _avatar(),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 18.sw,
                    height: 18.sw,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                )
              ],
            ),
            SizedBox(width: 14.sw),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name ?? "Nutritionist",
                    style: TextStyle(
                      color: purple,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      fontFamily: "Satoshi",
                    ),
                  ),
                  SizedBox(height: 4.sh),
                  Text(
                    email ?? "",
                    style: TextStyle(
                      color: purple.withValues(alpha: 0.6),
                      fontSize: 13.sp,
                      fontFamily: "Satoshi",
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

  Widget _avatar() {
    final hasNet = photoUrl != null && photoUrl!.trim().isNotEmpty;

    return Container(
      width: 60.sw,
      height: 60.sw,
      decoration: BoxDecoration(
        color: const Color(0xFFD9D9D9),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30.sw),
        child: hasNet
            ? Image.network(
                photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Image.asset(
                    "assets/logos/main_logo.png",
                    width: 21.sw,
                    height: 21.sh,
                    fit: BoxFit.contain,
                  ),
                ),
              )
            : Center(
                child: Image.asset(
                  "assets/logos/main_logo.png",
                  width: 30.sw,
                  height: 30.sh,
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
    Widget? trailingIcon,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 22.sw, vertical: 8.sh),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22.sw),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Ink(
            height: 70.sh,
            decoration: BoxDecoration(
              color: tileBg,
              borderRadius: BorderRadius.circular(22.sw),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            child: Row(
              children: [
                SizedBox(width: 18.sw),

                // Icon Container
                Container(
                  width: 44.sw,
                  height: 44.sw,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.9),
                        Colors.white.withValues(alpha: 0.4)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.6),
                        blurRadius: 6,
                        spreadRadius: 1,
                        offset: const Offset(-2, -2),
                      ),
                      BoxShadow(
                        color: purple.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(2, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: icon != null
                        ? Image.asset(icon, width: 20.sw, fit: BoxFit.contain)
                        : Icon(iconData, color: purple, size: 22.sw),
                  ),
                ),

                SizedBox(width: 14.sw),

                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: purple,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      fontFamily: "Satoshi",
                    ),
                  ),
                ),

                if (trailingIcon != null) ...[
                  trailingIcon,
                  SizedBox(width: 12.sw),
                ],

                Icon(Icons.arrow_forward_ios_rounded,
                    size: 16.sw, color: purple.withValues(alpha: 0.5)),

                SizedBox(width: 18.sw),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _deleteAccountButton() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 22.sw),
      child: GestureDetector(
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
                letterSpacing: 0.2,
                fontFamily: "Satoshi",
              ),
            ),
          ),
        ),
      ),
    );
  }
}
