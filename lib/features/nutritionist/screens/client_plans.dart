import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/core/utils/glass_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hidden_pantry_app/features/nutritionist/screens/create_plan.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';


class ClientPlansScreen extends StatefulWidget {
  const ClientPlansScreen({super.key});

  @override
  State<ClientPlansScreen> createState() => _ClientPlansScreenState();
}

class _ClientPlansScreenState extends State<ClientPlansScreen> {
  final Color purple = const Color(0xFF462F4D);
  final Color orange = const Color(0xFFEF8A54);

  void _editPlan(Map<String, dynamic> plan, String planId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreatePlanScreen(
          initialPlan: plan,
          planId: planId,
        ),
      ),
    );
  }

  void _confirmDelete(String planId) async {
    final confirmed = await GlassDialog.show<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text("Delete Plan?"),
        content: const Text("This action cannot be undone. Existing subscribers will lose access to future updates of this tier."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
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
            .collection("subscription_plans")
            .doc(planId)
            .delete();
        
        if (mounted) {
          Toaster.show(context, "Plan deleted");
        }
      } catch (e) {
        if (mounted) {
          Toaster.show(context, "Error: $e", isError: true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text("Not logged in"));
    }
    ResponsiveUtils.init(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("nutritionists")
                .doc(user.uid)
                .collection("subscription_plans")
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: orange));
              }

              final plans = snapshot.data?.docs ?? [];
              if (plans.isEmpty) return _emptyState(user.uid);

              return ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 22.sw),
                itemCount: plans.length + 1,
                itemBuilder: (context, index) {
                  if (index == plans.length) {
                    return Column(
                      children: [
                        SizedBox(height: 32.sh),
                        _publishAnotherButton(),
                        SizedBox(height: 120.sh),
                      ],
                    );
                  }

                  final doc = plans[index];
                  final plan = doc.data() as Map<String, dynamic>;
                  final planId = doc.id;

                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 600 + (index * 150)),
                    curve: Curves.easeOutQuart,
                    builder: (context, value, child) => Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 50 * (1 - value)),
                        child: child,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(top: 20.sh),
                      child: _planCard(
                        planId: planId,
                        plan: plan,
                        title: plan["title"] ?? "Untitled",
                        price: plan["price"]?.toString() ?? "0",
                        interval: plan["interval"] ?? "Monthly",
                        benefits: List<Map<String, dynamic>>.from(plan["benefits"] ?? []),
                        isActive: plan["isActive"] ?? true,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _header() {
    return Padding(
      padding: EdgeInsets.fromLTRB(22.sw, 24.sh, 22.sw, 12.sh),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(12.sw),
            decoration: BoxDecoration(
              color: orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16.sw),
            ),
            child: Icon(Icons.hub_rounded, color: orange, size: 28.sw),
          ),
          SizedBox(width: 16.sw),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Subscription Hub",
                  style: TextStyle(
                    color: purple,
                    fontSize: 28.sp,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Satoshi",
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  "Grow your premium community",
                  style: TextStyle(
                    color: purple.withValues(alpha: 0.5),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    fontFamily: "Satoshi",
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _planCard({
    required String planId,
    required Map<String, dynamic> plan,
    required String title,
    required String price,
    required String interval,
    required List<Map<String, dynamic>> benefits,
    required bool isActive,
  }) {
    return _PlanCardItem(
      planId: planId,
      plan: plan,
      title: title,
      price: price,
      interval: interval,
      benefits: benefits,
      isActive: isActive,
      onEdit: () => _editPlan(plan, planId),
      onDelete: () => _confirmDelete(planId),
    );
  }

  Widget _emptyState([String? uid]) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Start Monetizing",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: purple,
              fontSize: 24.sp,
              fontWeight: FontWeight.w900,
              fontFamily: "Satoshi",
            ),
          ),
          SizedBox(height: 12.sh),
          Text(
            "Create exclusive subscription tiers for your clients. Each nutritionist can set their own price and benefits.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: purple.withValues(alpha: 0.6),
              fontSize: 15.sp,
              height: 1.5,
              fontFamily: "Satoshi",
            ),
          ),
          if (uid != null) ...[
            SizedBox(height: 8.sh),
            Text(
              "Account ID: $uid",
              style: TextStyle(color: purple.withValues(alpha: 0.2), fontSize: 10.sp),
            ),
          ],
          SizedBox(height: 40.sh),
          _publishAnotherButton(),
        ],
      ),
    );
  }

  Widget _publishAnotherButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreatePlanScreen()),
        );
      },
      child: Container(
        height: 68.sh,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [purple, const Color(0xFF2D1E32)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24.sw),
          boxShadow: [
            BoxShadow(
              color: purple.withValues(alpha: 0.3),
              blurRadius: 25.sw,
              offset: Offset(0, 12.sh),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(6.sw),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add_rounded, color: Colors.white, size: 24.sw),
            ),
            SizedBox(width: 16.sw),
            Text(
              "Create New Tier",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.w900,
                fontFamily: "Satoshi",
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCardItem extends StatefulWidget {
  final String planId;
  final Map<String, dynamic> plan;
  final String title;
  final String price;
  final String interval;
  final List<Map<String, dynamic>> benefits;
  final bool isActive;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PlanCardItem({
    required this.planId,
    required this.plan,
    required this.title,
    required this.price,
    required this.interval,
    required this.benefits,
    required this.isActive,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_PlanCardItem> createState() => _PlanCardItemState();
}

class _PlanCardItemState extends State<_PlanCardItem> {
  late bool _currentActive;
  final Color purple = const Color(0xFF462F4D);
  final Color orange = const Color(0xFFEF8A54);

  @override
  void initState() {
    super.initState();
    _currentActive = widget.isActive;
  }

  @override
  void didUpdateWidget(_PlanCardItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _currentActive = widget.isActive;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tierColor = widget.plan["tierLevel"] == 3 
        ? const Color(0xFF673AB7) 
        : widget.plan["tierLevel"] == 2 
            ? const Color(0xFFDAA520) 
            : const Color(0xFF607D8B);

    return Container(
      padding: EdgeInsets.all(26.sw),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(32.sw),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: purple.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.sw, vertical: 6.sh),
                    decoration: BoxDecoration(
                      color: tierColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12.sw),
                      border: Border.all(color: tierColor.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.plan["tierLevel"] == 3 
                              ? Icons.diamond_rounded 
                              : widget.plan["tierLevel"] == 2 
                                  ? Icons.workspace_premium_rounded 
                                  : Icons.verified_user_rounded, 
                          size: 14.sw, 
                          color: tierColor
                        ),
                        SizedBox(width: 6.sw),
                        Text(
                          widget.plan["tierLevel"] == 3 ? "PLATINUM" : widget.plan["tierLevel"] == 2 ? "GOLD" : "SILVER",
                          style: TextStyle(
                            color: tierColor,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.sh),
                  Text(
                    widget.title,
                    style: TextStyle(
                      color: purple,
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w900,
                      fontFamily: "Satoshi",
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: purple.withValues(alpha: 0.04),
                  shape: BoxShape.circle,
                ),
                child: PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, color: purple.withValues(alpha: 0.4), size: 22.sw),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.sw)),
                  onSelected: (value) {
                    if (value == "edit") widget.onEdit();
                    if (value == "delete") widget.onDelete();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: "edit", 
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded, size: 18.sw, color: purple),
                          SizedBox(width: 12.sw),
                          const Text("Edit Tier"),
                        ],
                      )
                    ),
                    PopupMenuItem(
                      value: "delete", 
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 18.sw, color: Colors.red),
                          SizedBox(width: 12.sw),
                          const Text("Delete", style: TextStyle(color: Colors.red)),
                        ],
                      )
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 24.sh),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "Rs. ${widget.price}",
                style: TextStyle(
                  color: orange,
                  fontSize: 34.sp,
                  fontWeight: FontWeight.w900,
                  fontFamily: "Satoshi",
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: 8.sh, left: 6.sw),
                child: Text(
                  "/ ${widget.interval.toLowerCase()}",
                  style: TextStyle(
                    color: purple.withValues(alpha: 0.4),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 24.sh),
          Container(
            padding: EdgeInsets.all(18.sw),
            decoration: BoxDecoration(
              color: purple.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(24.sw),
            ),
            child: Column(
              children: [
                ...widget.benefits.map((b) => _benefitRow(b["title"] ?? b["text"] ?? "", true)),
              ],
            ),
          ),
          SizedBox(height: 24.sh),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("subscriptions")
                      .where("nutritionistId", isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                      .where("tierLevel", isEqualTo: widget.plan["tierLevel"] ?? 1)
                      .where("status", isEqualTo: "active")
                      .snapshots(),
                  builder: (context, subSnap) {
                    final int count = subSnap.data?.docs.length ?? 0;
                    double tierRevenue = 0;
                    if (subSnap.hasData && subSnap.data != null) {
                      for (var d in subSnap.data!.docs) {
                        final dData = d.data() as Map<String, dynamic>;
                        tierRevenue += (dData["price"] ?? 0.0).toDouble();
                      }
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.group_rounded, size: 14.sw, color: purple.withValues(alpha: 0.4)),
                            SizedBox(width: 6.sw),
                            Text(
                              "$count ACTIVE CLIENTS",
                              style: TextStyle(
                                color: purple.withValues(alpha: 0.5),
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4.sh),
                        Text(
                          "EST. REVENUE: Rs. ${tierRevenue.toInt()}",
                          style: TextStyle(
                            color: orange.withValues(alpha: 0.8),
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    );
                  }
                ),
              ),
              Column(
                children: [
                  Text(
                    _currentActive ? "VISIBLE" : "HIDDEN",
                    style: TextStyle(
                      color: _currentActive ? Colors.green : Colors.red,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: _currentActive,
                      onChanged: (v) async {
                        setState(() => _currentActive = v);
                        try {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user == null) return;
                          await FirebaseFirestore.instance
                              .collection("nutritionists")
                              .doc(user.uid)
                              .collection("subscription_plans")
                              .doc(widget.planId)
                              .update({"isActive": v, "updatedAt": FieldValue.serverTimestamp()});
                        } catch (e) {
                          setState(() => _currentActive = !v);
                          if (mounted) {
                            Toaster.show(context, "Error: $e", isError: true);
                          }
                        }
                      },
                      activeColor: orange,
                      activeTrackColor: orange.withValues(alpha: 0.2),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _benefitRow(String text, bool active) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.sh),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(4.sw),
            decoration: BoxDecoration(
              color: orange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_rounded, color: orange, size: 10.sw),
          ),
          SizedBox(width: 12.sw),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: purple.withValues(alpha: 0.8),
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                fontFamily: "Satoshi",
              ),
            ),
          ),
        ],
      ),
    );
  }
}
