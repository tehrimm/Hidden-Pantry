import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';
import 'package:hidden_pantry_app/features/onboarding/screens/loading_five.dart';


class NutritionistPendingScreen extends StatelessWidget {
  const NutritionistPendingScreen({super.key});

  static const Color bg = Color(0xFFFFF3EB);
  static const Color purple = Color(0xFF462F4D);
  static const Color brown = Color(0xFF433020);
  static const Color tileBg = Color(0xFFF9E3D5);
  static const Color orange = Color(0xFFEF8A54);

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    return Scaffold(
      backgroundColor: bg,
      body: Container(
        color: bg,
        child: Stack(
          children: [
            const PatternBackground(),

            // Content
            SafeArea(
              child: Column(
                children: [
                  SizedBox(height: 80.sh), // Space for fixed header
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 40.sw),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Clock icon
                            Container(
                              width: 100.sw,
                              height: 100.sw,
                              decoration: BoxDecoration(
                                color: tileBg,
                                borderRadius: BorderRadius.circular(50.sw),
                              ),
                              child: Icon(
                                Icons.schedule,
                                size: 50.sw,
                                color: orange,
                              ),
                            ),

                            SizedBox(height: 30.sh),

                            // Title
                            Text(
                              "Pending Approval",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: purple,
                                fontSize: 28.sp,
                                fontWeight: FontWeight.w900,
                                fontFamily: "Satoshi",
                              ),
                            ),

                            SizedBox(height: 20.sh),

                            // Message
                            Opacity(
                              opacity: 0.7,
                              child: Text(
                                "Your account is currently pending approval. We'll notify you once your certificate has been reviewed.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: purple,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500,
                                  height: 1.5,
                                  fontFamily: "Satoshi",
                                ),
                              ),
                            ),

                            SizedBox(height: 40.sh),

                            // Back to home button
                            GestureDetector(
                              onTap: () {
                                Navigator.pushReplacement(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (_, __, ___) => const LoadingFive(),
                                    transitionDuration: const Duration(milliseconds: 400),
                                    transitionsBuilder: (_, anim, __, child) =>
                                      FadeTransition(opacity: anim, child: child),
                                  ),
                                );
                              },
                              child: Container(
                                width: double.infinity,
                                height: 70.sh,
                                decoration: BoxDecoration(
                                  color: orange,
                                  borderRadius: BorderRadius.circular(20.sw),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "Back to Home",
                                  style: TextStyle(
                                    color: const Color(0xFFFFF2EA),
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
                  ),
                ],
              ),
            ),

            // Fixed header - back button
            Positioned(
              left: 30.sw,
              top: 51.sh,
              child: BackButtonWidget(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) => const LoadingFive(),
                      transitionDuration: const Duration(milliseconds: 400),
                      transitionsBuilder: (_, anim, __, child) =>
                        FadeTransition(opacity: anim, child: child),
                    ),
                  );
                },
                color: brown,
              ),
            ),
            // Fixed header - title
            Positioned(
              left: 0,
              right: 0,
              top: 51.sh,
              height: 50.sh,
              child: Center(
                child: Text(
                  "Certificate Status",
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
      ),
    );
  }
}
