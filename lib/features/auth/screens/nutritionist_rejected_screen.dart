import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';

import 'package:hidden_pantry_app/features/onboarding/screens/loading_five.dart';
import 'package:hidden_pantry_app/features/nutritionist/services/nutritionist_service.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';

class NutritionistRejectedScreen extends StatefulWidget {
  final String rejectionReason;
  final String uid;

  const NutritionistRejectedScreen({
    super.key,
    required this.rejectionReason,
    required this.uid,
  });

  @override
  State<NutritionistRejectedScreen> createState() => _NutritionistRejectedScreenState();
}

class _NutritionistRejectedScreenState extends State<NutritionistRejectedScreen> {
  final NutritionistService _service = const NutritionistService();
  bool _deleting = false;

  static const Color bg = Color(0xFFFFF3EB);
  static const Color purple = Color(0xFF462F4D);
  static const Color btnRed = Color(0xFFFD3250);
  static const Color btnText = Color(0xFFFFF2EA);

  // Base size
  // Removed manual scaling constants

  @override
  void initState() {
    super.initState();
    // Mark that user has logged in after rejection (prevents auto-deletion)
    _markLoggedIn();
  }

  Future<void> _markLoggedIn() async {
    try {
      await _service.markLoggedInAfterRejection(widget.uid);
      debugPrint("Marked user as logged in after rejection");
    } catch (e) {
      debugPrint("Error marking login: $e");
    }
  }

  Future<void> _deleteAccount() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          "Delete Account?",
          style: TextStyle(
            color: purple,
            fontWeight: FontWeight.bold,
            fontFamily: "Satoshi",
          ),
        ),
        content: Text(
          "This action cannot be undone. Your account and all data will be permanently deleted.",
          style: TextStyle(
            color: purple,
            fontFamily: "Satoshi",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "Cancel",
              style: TextStyle(
                color: purple,
                fontFamily: "Satoshi",
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              "Delete",
              style: TextStyle(
                color: btnRed,
                fontWeight: FontWeight.bold,
                fontFamily: "Satoshi",
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _deleting = true);

    try {
      // Delete account
      await _service.deleteNutritionist(widget.uid);
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      // Navigate to starting page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoadingFive()),
      );
    } catch (e) {
      debugPrint("Error deleting account: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error deleting account: $e")),
        );
        setState(() => _deleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: SizedBox(
          width: 393.sw,
          height: 852.sh,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30.sw),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                const PatternBackground(),

                // Back button
                Positioned(
                  left: 30.sw,
                  top: 51.sh,
                  child: const BackButtonWidget(),
                ),

                // Content
                Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40.sw),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Warning icon
                        Container(
                          width: 100.sw,
                          height: 100.sw,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE0DD),
                            borderRadius: BorderRadius.circular(50.sw),
                          ),
                          child: Icon(
                            Icons.warning_rounded,
                            size: 50.sw,
                            color: btnRed,
                          ),
                        ),

                        SizedBox(height: 30.sh),

                        // Title
                        Text(
                          "Verification Rejected",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: purple,
                            fontSize: 32.sp,
                            fontWeight: FontWeight.w900,
                            fontFamily: "Satoshi",
                          ),
                        ),

                        SizedBox(height: 20.sh),

                        // Rejection reason
                        Container(
                          padding: EdgeInsets.all(20.sw),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9E3D5),
                            borderRadius: BorderRadius.circular(15.sw),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Reason:",
                                style: TextStyle(
                                  color: purple,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: "Satoshi",
                                ),
                              ),
                              SizedBox(height: 8.sh),
                              Text(
                                widget.rejectionReason,
                                style: TextStyle(
                                  color: purple,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500,
                                  height: 1.5,
                                  fontFamily: "Satoshi",
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 40.sh),

                        // Delete account button
                        GestureDetector(
                          onTap: _deleting ? null : _deleteAccount,
                          child: Container(
                            width: 280.sw,
                            height: 62.sh,
                            decoration: BoxDecoration(
                              color: btnRed,
                              borderRadius: BorderRadius.circular(20.sw),
                            ),
                            alignment: Alignment.center,
                            child: _deleting
                                ? SizedBox(
                                    width: 18.sw,
                                    height: 18.sw,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    "Delete Account Now",
                                    style: TextStyle(
                                      color: btnText,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: "Satoshi",
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



