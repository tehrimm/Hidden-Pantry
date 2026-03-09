import 'package:flutter/material.dart';
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
  final Color cardColor = const Color(0xFFF9E3D5);

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    final user = FirebaseAuth.instance.currentUser;
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          const PatternBackground(),
          
          SafeArea(
            child: Column(
              children: [
                SizedBox(height: 96.sh), // Standardized gap for fixed header
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
                                    Icon(Icons.assignment_rounded, size: 80.sp, color: purple.withValues(alpha:0.1)),
                                    SizedBox(height: 20.sh),
                                    Text("No Saved Plans Yet", style: TextStyle(color: purple, fontSize: 18.sp, fontWeight: FontWeight.bold, fontFamily: "Satoshi")),
                                    SizedBox(height: 8.sh),
                                    Text(
                                      "Ask your nutritionist to share a plan\nwith you in the chat.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: purple.withValues(alpha:0.5), fontSize: 14.sp, fontFamily: "Satoshi"),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return ListView.separated(
                              padding: EdgeInsets.symmetric(horizontal: 24.sw, vertical: 20.sh),
                              itemCount: docs.length,
                              separatorBuilder: (_, __) => SizedBox(height: 16.sh),
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
                                    padding: EdgeInsets.all(20.sw),
                                    decoration: BoxDecoration(
                                      color: cardColor,
                                      borderRadius: BorderRadius.circular(20.sw),
                                      boxShadow: [
                                        BoxShadow(color: purple.withValues(alpha:0.05), blurRadius: 10, offset: const Offset(0, 5))
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(12.sw),
                                          decoration: BoxDecoration(
                                            color: orange.withValues(alpha:0.1),
                                            borderRadius: BorderRadius.circular(16.sw),
                                          ),
                                          child: Icon(Icons.restaurant_menu_rounded, color: orange, size: 28.sp),
                                        ),
                                        SizedBox(width: 16.sw),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                title,
                                                style: TextStyle(color: purple, fontSize: 18.sp, fontWeight: FontWeight.bold, fontFamily: "Satoshi"),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              SizedBox(height: 6.sh),
                                              Text(
                                                "$duration Days • ~ $targetCalories kcal",
                                                style: TextStyle(color: purple.withValues(alpha:0.6), fontSize: 13.sp, fontWeight: FontWeight.w500),

                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(Icons.arrow_forward_ios_rounded, color: purple.withValues(alpha:0.3), size: 16.sp),
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
            left: 30.sw,
            top: topPad + 36.sh,
            child: BackButtonWidget(color: purple),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: topPad + 36.sh,
            height: 50.sh,
            child: Center(
              child: Text(
                "My Plans",
                style: TextStyle(
                  color: purple,
                  fontSize: 24.sp,
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
