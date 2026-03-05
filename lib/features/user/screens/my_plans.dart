import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/features/user/screens/meal_plan_view.dart';

class MyPlansScreen extends StatelessWidget {
  const MyPlansScreen({super.key});

  final Color bg = const Color(0xFFFFF3EB);
  final Color purple = const Color(0xFF462F4D);
  final Color orange = const Color(0xFFEF8A54);
  final Color cardColor = const Color(0xFFF9E3D5);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          const PatternBackground(),
          
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 70), // Header space
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
                              return Center(child: Text("Error loading plans: ${snapshot.error}", style: TextStyle(color: purple)));
                            }
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return Center(child: CircularProgressIndicator(color: orange));
                            }
                            
                            final docs = snapshot.data?.docs ?? [];
                            
                            if (docs.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.assignment_rounded, size: 80, color: purple.withValues(alpha:0.1)),
                                    const SizedBox(height: 20),
                                    Text("No Saved Plans Yet", style: TextStyle(color: purple, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: "Satoshi")),
                                    const SizedBox(height: 8),
                                    Text(
                                      "Ask your nutritionist to share a plan\nwith you in the chat.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: purple.withValues(alpha:0.5), fontSize: 14, fontFamily: "Satoshi"),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                              itemCount: docs.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 16),
                              itemBuilder: (context, index) {
                                final planData = docs[index].data() as Map<String, dynamic>;
                                final title = planData["title"] ?? "Untitled Plan";
                                final duration = planData["duration"] ?? 0;
                                final targetCalories = planData["targetCalories"] ?? "0";

                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => MealPlanViewScreen(planData: planData, isViewingSavedPlan: true),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: cardColor,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(color: purple.withValues(alpha:0.05), blurRadius: 10, offset: const Offset(0, 5))
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: orange.withValues(alpha:0.1),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Icon(Icons.restaurant_menu_rounded, color: orange, size: 28),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                title,
                                                style: TextStyle(color: purple, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: "Satoshi"),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                "$duration Days • ~ $targetCalories kcal",
                                                style: TextStyle(color: purple.withValues(alpha:0.6), fontSize: 13, fontWeight: FontWeight.w500),

                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(Icons.arrow_forward_ios_rounded, color: purple.withValues(alpha:0.3), size: 16),
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
          
          Positioned(
            left: 30,
            top: 51,
            child: BackButtonWidget(color: purple),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 51,
            height: 50,
            child: Center(
              child: Text(
                "My Plans",
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
    );
  }
}
