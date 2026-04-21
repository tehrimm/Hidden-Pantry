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
                return const Center(child: CircularProgressIndicator());
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

                  return Padding(
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
      padding: EdgeInsets.symmetric(horizontal: 22.sw, vertical: 16.sh),
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
            ),
          ),
          Text(
            "Grow your premium community",
            style: TextStyle(
              color: purple.withValues(alpha: 0.6),
              fontSize: 14.sp,
              fontFamily: "Satoshi",
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
        height: 64.sh,
        width: double.infinity,
        decoration: BoxDecoration(
          color: purple,
          borderRadius: BorderRadius.circular(20.sw),
          boxShadow: [
            BoxShadow(
              color: purple.withValues(alpha: 0.3),
              blurRadius: 20.sw,
              offset: Offset(0, 10.sh),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: Colors.white, size: 24.sw),
            SizedBox(width: 12.sw),
            Text(
              "Create New Tier",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                fontFamily: "Satoshi",
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
    return Container(
      padding: EdgeInsets.all(24.sw),
      decoration: BoxDecoration(
        color: const Color(0xFFF9E3D5),
        borderRadius: BorderRadius.circular(24.sw),
        boxShadow: [
          BoxShadow(
            color: purple.withValues(alpha: 0.05),
            blurRadius: 15.sw,
            offset: Offset(0, 8.sh),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: TextStyle(
                  color: purple,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w900,
                  fontFamily: "Satoshi",
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz_rounded, color: purple.withValues(alpha: 0.3)),
                onSelected: (value) {
                  if (value == "edit") widget.onEdit();
                  if (value == "delete") widget.onDelete();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: "edit", child: Text("Edit")),
                  const PopupMenuItem(value: "delete", child: Text("Delete", style: TextStyle(color: Colors.red))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
               Container(
                padding: EdgeInsets.symmetric(horizontal: 10.sw, vertical: 5.sh),
                decoration: BoxDecoration(
                  color: (widget.plan["tierLevel"] == 3 
                    ? const Color(0xFF4B0082) 
                    : widget.plan["tierLevel"] == 2 
                      ? const Color(0xFFDAA520) 
                      : const Color(0xFF708090)).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10.sw),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.plan["tierLevel"] == 3 
                        ? Icons.diamond_rounded 
                        : widget.plan["tierLevel"] == 2 
                          ? Icons.star_rounded 
                          : Icons.star_half_rounded, 
                      size: 12.sw, 
                      color: widget.plan["tierLevel"] == 3 
                        ? const Color(0xFF4B0082) 
                        : widget.plan["tierLevel"] == 2 
                          ? const Color(0xFFDAA520) 
                          : const Color(0xFF708090)
                    ),
                    SizedBox(width: 4.sw),
                    Text(
                      widget.plan["tierLevel"] == 3 ? "PLATINUM" : widget.plan["tierLevel"] == 2 ? "GOLD" : "SILVER",
                      style: TextStyle(
                        color: widget.plan["tierLevel"] == 3 
                          ? const Color(0xFF4B0082) 
                          : widget.plan["tierLevel"] == 2 
                            ? const Color(0xFFDAA520) 
                            : const Color(0xFF708090),
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.sw),
              if (!_currentActive)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.sw, vertical: 5.sh),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10.sw),
                  ),
                  child: Text("HIDDEN", style: TextStyle(color: Colors.red, fontSize: 10.sp, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          SizedBox(height: 12.sh),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "Rs. ${widget.price}",
                style: TextStyle(
                  color: orange,
                  fontSize: 30.sp,
                  fontWeight: FontWeight.w900,
                  fontFamily: "Satoshi",
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: 6.sh, left: 4.sw),
                child: Text(
                  "/ ${widget.interval}",
                  style: TextStyle(
                    color: purple.withValues(alpha: 0.4),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20.sh),
          ...widget.benefits.map((b) => _benefitRow(b["title"] ?? b["text"] ?? "", true)),
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
                    return Row(
                      children: [
                          Text(
                            "$count ACTIVE CLIENTS",
                            style: TextStyle(
                              color: purple.withValues(alpha: 0.4),
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5.sw,
                            ),
                          ),
                        const Spacer(),
                        Text(
                          "VAL: Rs. ${tierRevenue.toInt()}",
                          style: TextStyle(
                            color: orange.withValues(alpha: 0.6),
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    );
                  }
                ),
              ),
              Switch(
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
                activeThumbColor: orange,
                activeTrackColor: orange.withValues(alpha: 0.1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _benefitRow(String text, bool active) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.sh),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: purple,
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                fontFamily: "Satoshi",
              ),
            ),
          ),
        ],
      ),
    );
  }
}
