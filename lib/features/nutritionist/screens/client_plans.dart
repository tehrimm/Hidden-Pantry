import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hidden_pantry_app/features/nutritionist/screens/create_plan.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';

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
    final confirmed = await showDialog<bool>(
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
                padding: const EdgeInsets.symmetric(horizontal: 22),
                itemCount: plans.length + 1,
                itemBuilder: (context, index) {
                  if (index == plans.length) {
                    return Column(
                      children: [
                        const SizedBox(height: 32),
                        _publishAnotherButton(),
                        const SizedBox(height: 120),
                      ],
                    );
                  }

                  final doc = plans[index];
                  final plan = doc.data() as Map<String, dynamic>;
                  final planId = doc.id;

                  return Padding(
                    padding: const EdgeInsets.only(top: 20),
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
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Subscription Hub",
            style: TextStyle(
              color: purple,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              fontFamily: "Satoshi",
            ),
          ),
          Text(
            "Grow your premium community",
            style: TextStyle(
              color: purple.withValues(alpha: 0.6),
              fontSize: 14,
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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF9E3D5),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: purple.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
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
                title,
                style: TextStyle(
                  color: purple,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  fontFamily: "Satoshi",
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz_rounded, color: purple.withValues(alpha: 0.3)),
                onSelected: (value) {
                  if (value == "edit") _editPlan(plan, planId);
                  if (value == "delete") _confirmDelete(planId);
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (plan["tierLevel"] == 3 
                    ? const Color(0xFF4B0082) 
                    : plan["tierLevel"] == 2 
                      ? const Color(0xFFDAA520) 
                      : const Color(0xFF708090)).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      plan["tierLevel"] == 3 
                        ? Icons.diamond_rounded 
                        : plan["tierLevel"] == 2 
                          ? Icons.star_rounded 
                          : Icons.star_half_rounded, 
                      size: 12, 
                      color: plan["tierLevel"] == 3 
                        ? const Color(0xFF4B0082) 
                        : plan["tierLevel"] == 2 
                          ? const Color(0xFFDAA520) 
                          : const Color(0xFF708090)
                    ),
                    const SizedBox(width: 4),
                    Text(
                      plan["tierLevel"] == 3 ? "PLATINUM" : plan["tierLevel"] == 2 ? "GOLD" : "SILVER",
                      style: TextStyle(
                        color: plan["tierLevel"] == 3 
                          ? const Color(0xFF4B0082) 
                          : plan["tierLevel"] == 2 
                            ? const Color(0xFFDAA520) 
                            : const Color(0xFF708090),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text("HIDDEN", style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "Rs. $price",
                style: TextStyle(
                  color: orange,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  fontFamily: "Satoshi",
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 4),
                child: Text(
                  "/ $interval",
                  style: TextStyle(
                    color: purple.withValues(alpha: 0.4),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...benefits.map((b) => _benefitRow(b["title"] ?? b["text"] ?? "", true)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("subscriptions")
                      .where("nutritionistId", isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                      .where("tierLevel", isEqualTo: plan["tierLevel"] ?? 1)
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
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          "VAL: Rs. ${tierRevenue.toInt()}",
                          style: TextStyle(
                            color: orange.withValues(alpha: 0.6),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    );
                  }
                ),
              ),
              Switch(
                value: isActive,
                onChanged: (v) async {
                  try {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) return;
                    await FirebaseFirestore.instance
                        .collection("nutritionists")
                        .doc(user.uid)
                        .collection("subscription_plans")
                        .doc(planId)
                        .update({"isActive": v, "updatedAt": FieldValue.serverTimestamp()});
                  } catch (e) {
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: purple,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                fontFamily: "Satoshi",
              ),
            ),
          ),
        ],
      ),
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
              fontSize: 24,
              fontWeight: FontWeight.w900,
              fontFamily: "Satoshi",
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Create exclusive subscription tiers for your clients. Each nutritionist can set their own price and benefits.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: purple.withValues(alpha: 0.6),
              fontSize: 15,
              height: 1.5,
              fontFamily: "Satoshi",
            ),
          ),
          if (uid != null) ...[
            const SizedBox(height: 8),
            Text(
              "Account ID: $uid",
              style: TextStyle(color: purple.withValues(alpha: 0.2), fontSize: 10),
            ),
          ],
          const SizedBox(height: 40),
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
        height: 64,
        width: double.infinity,
        decoration: BoxDecoration(
          color: purple,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: purple.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_rounded, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            const Text(
              "Create New Tier",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
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
