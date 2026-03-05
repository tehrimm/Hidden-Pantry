import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
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
                  const SizedBox(height: 80), // Space for fixed header
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Clock icon
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: tileBg,
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: const Icon(
                                Icons.schedule,
                                size: 50,
                                color: orange,
                              ),
                            ),

                            const SizedBox(height: 30),

                            // Title
                            const Text(
                              "Pending Approval",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: purple,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                fontFamily: "Satoshi",
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Message
                            const Opacity(
                              opacity: 0.7,
                              child: Text(
                                "Your account is currently pending approval. We'll notify you once your certificate has been reviewed.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: purple,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  height: 1.5,
                                  fontFamily: "Satoshi",
                                ),
                              ),
                            ),

                            const SizedBox(height: 40),

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
                                height: 70,
                                decoration: BoxDecoration(
                                  color: orange,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                alignment: Alignment.center,
                                child: const Text(
                                  "Back to Home",
                                  style: TextStyle(
                                    color: Color(0xFFFFF2EA),
                                    fontSize: 14,
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
              left: 30,
              top: 51,
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
            const Positioned(
              left: 0,
              right: 0,
              top: 51,
              height: 50,
              child: Center(
                child: Text(
                  "Certificate Status",
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
      ),
    );
  }
}
