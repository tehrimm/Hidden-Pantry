import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/features/user/screens/meal_plan_view.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';


class MyPlansScreen extends StatelessWidget {
  const MyPlansScreen({super.key});

  final Color bg = const Color(0xFFFFF3EB);
  final Color purple = const Color(0xFF462F4D);
  final Color orange = const Color(0xFFEF8A54);

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    final user = FirebaseAuth.instance.currentUser;
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFF3EB), Color(0xFFF6DFD1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.4, 1.0],
              ),
            ),
          ),
          
          // Decorative Orbs
          const _MyPlansBackgroundPattern(),

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

          SafeArea(
            child: Column(
              children: [
                SizedBox(height: 96.sh),
                Expanded(
                  child: user == null
                      ? const Center(child: Text("Please log in to view saved plans"))
                      : StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection("users")
                              .doc(user.uid)
                              .collection("saved_meal_plans")
                              .orderBy("savedAt", descending: true)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Center(child: Text("Error loading plans", style: TextStyle(color: purple)));
                            }
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return Center(child: CircularProgressIndicator(color: orange, strokeWidth: 2.5));
                            }

                            final docs = snapshot.data?.docs ?? [];

                            if (docs.isEmpty) {
                              return _FadeSlideEntry(
                                delayMs: 200,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 90.sw, height: 90.sw,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            colors: [orange.withValues(alpha: 0.15), orange.withValues(alpha: 0.05)],
                                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                                          ),
                                          boxShadow: [
                                            BoxShadow(color: orange.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 8)),
                                          ],
                                        ),
                                        child: Icon(Icons.restaurant_menu_rounded, color: orange, size: 40.sw),
                                      ),
                                      SizedBox(height: 24.sh),
                                      Text("No Saved Plans Yet",
                                        style: TextStyle(color: purple, fontSize: 18.sp, fontWeight: FontWeight.w700, fontFamily: "Satoshi")),
                                      SizedBox(height: 8.sh),
                                      Text(
                                        "Ask your nutritionist to share a plan\nwith you in the chat.",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: purple.withValues(alpha: 0.45), fontSize: 14.sp, fontWeight: FontWeight.w500, fontFamily: "Satoshi", height: 1.5),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            int animIndex = 0;
                            return ListView.separated(
                              padding: EdgeInsets.symmetric(horizontal: 24.sw, vertical: 20.sh),
                              itemCount: docs.length,
                              separatorBuilder: (_, __) => SizedBox(height: 14.sh),
                              itemBuilder: (context, index) {
                                animIndex++;
                                final planData = docs[index].data() as Map<String, dynamic>;
                                final title = planData["title"] ?? "Untitled Plan";
                                final duration = planData["duration"] ?? 0;
                                final targetCalories = planData["targetCalories"] ?? "0";

                                return _FadeSlideEntry(
                                  delayMs: 100 + (animIndex * 100),
                                  child: _buildPlanCard(context, planData, title, duration, targetCalories),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),

          // Fixed Header
          Positioned(
            left: 30.sw, top: topPad + 36.sh,
            child: BackButtonWidget(color: purple),
          ),
          Positioned(
            left: 0, right: 0, top: topPad + 36.sh, height: 50.sh,
            child: Center(
              child: Text("My Plans",
                style: TextStyle(color: purple, fontSize: 24.sp, fontWeight: FontWeight.bold, fontFamily: "Satoshi")),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(BuildContext context, Map<String, dynamic> planData, String title, dynamic duration, dynamic targetCalories) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(22.sw),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 6)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22.sw),
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => MealPlanViewScreen(planData: planData, isViewingSavedPlan: true),
            ));
          },
          child: Padding(
            padding: EdgeInsets.all(18.sw),
            child: Row(
              children: [
                // Icon circle
                Container(
                  width: 52.sw, height: 52.sw,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [orange.withValues(alpha: 0.2), orange.withValues(alpha: 0.05)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(color: orange.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Icon(Icons.restaurant_menu_rounded, color: orange, size: 24.sw),
                ),
                SizedBox(width: 16.sw),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                        style: TextStyle(color: purple, fontSize: 16.sp, fontWeight: FontWeight.w700, fontFamily: "Satoshi"),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      SizedBox(height: 6.sh),
                      Row(
                        children: [
                          _infoPill(Icons.calendar_today_rounded, "$duration Days"),
                          SizedBox(width: 8.sw),
                          _infoPill(Icons.local_fire_department_rounded, "$targetCalories kcal"),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: purple.withValues(alpha: 0.25), size: 16.sw),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoPill(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.sw, vertical: 4.sh),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10.sw),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.sw, color: orange),
          SizedBox(width: 4.sw),
          Text(text, style: TextStyle(color: purple.withValues(alpha: 0.55), fontSize: 11.sp, fontWeight: FontWeight.w600, fontFamily: "Satoshi")),
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

class _MyPlansBackgroundPattern extends StatelessWidget {
  const _MyPlansBackgroundPattern();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -50.sh,
            right: -80.sw,
            child: _MyPlansFloatingOrb(
              color: const Color(0xFFFFE0D3).withValues(alpha: 0.5),
              size: 350,
              duration: const Duration(seconds: 15),
            ),
          ),
          Positioned(
            bottom: 50.sh,
            left: -100.sw,
            child: _MyPlansFloatingOrb(
              color: const Color(0xFFEF8A54).withValues(alpha: 0.08),
              size: 450,
              duration: const Duration(seconds: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _MyPlansFloatingOrb extends StatefulWidget {
  final Color color;
  final double size;
  final Duration duration;

  const _MyPlansFloatingOrb({required this.color, required this.size, required this.duration});

  @override
  State<_MyPlansFloatingOrb> createState() => _MyPlansFloatingOrbState();
}

class _MyPlansFloatingOrbState extends State<_MyPlansFloatingOrb> with SingleTickerProviderStateMixin {
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
        final double angle = _controller.value * 2 * 3.14159;
        return Transform.translate(
          offset: Offset(math.cos(angle) * 20, math.sin(angle) * 40),
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
