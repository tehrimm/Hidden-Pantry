import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'signup_nutritionist.dart';
import 'nutritionist_pending_screen.dart';
import 'nutritionist_rejected_screen.dart';
import 'package:hidden_pantry_app/features/nutritionist/screens/nutritionist_dashboard.dart';

/// Wrapper that checks nutritionist status and routes to appropriate screen
class NutritionistSignupWrapper extends StatefulWidget {
  const NutritionistSignupWrapper({super.key});

  @override
  State<NutritionistSignupWrapper> createState() => _NutritionistSignupWrapperState();
}

class _NutritionistSignupWrapperState extends State<NutritionistSignupWrapper> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const SignupNutritionistScreen();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('nutritionists')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
           return const Scaffold(
            backgroundColor: Color(0xFFFFF3EB),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFFF2894F),
              ),
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SignupNutritionistScreen();
        }

        final data = snapshot.data!.data();
        final status = data?['verificationStatus'] as String?;

        if (status == 'pending') {
          return const NutritionistPendingScreen();
        } else if (status == 'rejected') {
          final reason = data?['rejectionReason'] as String? ?? 'No reason provided';
          return NutritionistRejectedScreen(
            rejectionReason: reason,
            uid: user.uid,
          );
        } else if (status == 'approved') {
          return const NutritionistDashboard();
        } else {
          return const SignupNutritionistScreen();
        }
      },
    );
  }
}



