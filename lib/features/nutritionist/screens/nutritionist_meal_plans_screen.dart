import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/core/utils/glass_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hidden_pantry_app/features/nutritionist/screens/meal_plan_creator.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';

class NutritionistMealPlansScreen extends StatefulWidget {
  const NutritionistMealPlansScreen({super.key});

  @override
  State<NutritionistMealPlansScreen> createState() => _NutritionistMealPlansScreenState();
}

class _NutritionistMealPlansScreenState extends State<NutritionistMealPlansScreen> {
  final Color bg = const Color(0xFFFFF7F2);
  final Color purple = const Color(0xFF462F4D);
  final Color orange = const Color(0xFFEF8A54);
  final Color cardBg = const Color(0xFFF9E3D5);

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text("Not logged in")));

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          const PatternBackground(),
          SafeArea(
            child: Column(
              children: [
                SizedBox(height: 12.sh),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 22.sw),
                  child: Row(
                    children: [
                      const BackButtonWidget(),
                      SizedBox(width: 16.sw),
                      Text(
                        "My Meal Plans",
                        style: TextStyle(
                          color: purple,
                          fontSize: 26.sp,
                          fontWeight: FontWeight.w900,
                          fontFamily: "Satoshi",
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20.sh),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection("nutritionists")
                        .doc(user.uid)
                        .collection("meal_plans")
                        .orderBy("updatedAt", descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return _emptyState();
                      }

                      return ListView.separated(
                        padding: EdgeInsets.only(left: 22.sw, right: 22.sw, top: 10.sh, bottom: 120.sh),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => SizedBox(height: 16.sh),
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          final id = docs[index].id;
                          return _mealPlanCard(id, data);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Positioned "Create New Plan" button - moved "up and left"
          Positioned(
            bottom: 40.sh,
            right: 30.sw,
            child: FloatingActionButton.extended(
              elevation: 4.sw,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MealPlanCreatorScreen()),
                );
              },
              backgroundColor: purple,
              label: Text("Create New Plan", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontFamily: "Satoshi", fontSize: 14.sp)),
              icon: Icon(Icons.add_rounded, color: Colors.white, size: 24.sw),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mealPlanCard(String id, Map<String, dynamic> data) {
    final title = data["title"] ?? "Untitled Plan";
    final days = data["duration"] ?? 0;
    final cals = data["targetCalories"] ?? 0;

    return _FadeSlideEntry(
      delayMs: 100,
      child: Container(
        padding: EdgeInsets.all(16.sw),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20.sw),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.sw),
              decoration: BoxDecoration(
                color: orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(15.sw),
              ),
              child: Icon(Icons.restaurant_menu_rounded, color: orange, size: 24.sw),
            ),
            SizedBox(width: 16.sw),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 16.sp, fontFamily: "Satoshi"),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.sh),
                  Text(
                    "$days Days • ~ $cals kcal",
                    style: TextStyle(color: purple.withValues(alpha: 0.5), fontSize: 13.sp),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.edit_rounded, color: orange, size: 22.sw),
              onPressed: () {
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
            ),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: Colors.red.withValues(alpha: 0.6), size: 22.sw),
              onPressed: () => _confirmDelete(id),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(String id) async {
    final confirmed = await GlassDialog.show<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.sw)),
        title: Text("Delete Meal Plan?", style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: purple)),
        content: Text("This action cannot be undone.", style: TextStyle(fontSize: 14.sp, color: purple)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("Cancel", style: TextStyle(color: purple, fontSize: 14.sp))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("Delete", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14.sp)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;
        await FirebaseFirestore.instance
            .collection("nutritionists")
            .doc(user.uid)
            .collection("meal_plans")
            .doc(id)
            .delete();
        if (mounted) Toaster.show(context, "Meal plan deleted");
      } catch (e) {
        if (mounted) Toaster.show(context, "Error: $e", isError: true);
      }
    }
  }

  Widget _emptyState() {
     return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_rounded, size: 64.sw, color: purple.withValues(alpha: 0.1)),
          SizedBox(height: 16.sh),
          Text(
            "No Meal Plans Yet",
            style: TextStyle(color: purple, fontSize: 18.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8.sh),
          Text(
            "Create plans to share with your subscribers.",
            style: TextStyle(color: purple.withValues(alpha: 0.5), fontSize: 14.sp),
          ),
        ],
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
    _slide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    if (widget.delayMs > 0) {
      Future.delayed(Duration(milliseconds: widget.delayMs), () {
        if (mounted) _ctrl.forward();
      });
    } else {
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}
