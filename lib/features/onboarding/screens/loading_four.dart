import 'package:flutter/material.dart';
import 'loading_one.dart'; // Ensure OnboardingProgressBar is available
import 'loading_three.dart';
import 'terms_and_condition.dart';
import 'loading_five.dart';

class LoadingFour extends StatelessWidget {
  const LoadingFour({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const LoadingThree(),
          ),
        );
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF3EB),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final double screenWidth = constraints.maxWidth;
            final double screenHeight = constraints.maxHeight;

            const double designWidth = 393.0;
            const double designHeight = 852.0;

            final double wScale = screenWidth / designWidth;
            final double hScale = screenHeight / designHeight;

            return SizedBox(
              width: screenWidth,
              height: screenHeight,
              child: Stack(
                children: [
                  Positioned(
                    left: 26 * wScale,
                    top: 34 * hScale,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(40),
                      child: SizedBox(
                        width: 341 * wScale,
                        height: 788 * hScale,
                        child: Image.asset(
                          'assets/bg/6.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    top: 62 * hScale,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Image.asset(
                        'assets/logos/logo.png',
                        width: 113 * wScale,
                        height: 26 * hScale,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  Positioned(
                    left: 52 * wScale,
                    top: 555 * hScale,
                    child: SizedBox(
                      width: 330 * wScale,
                      child: Text(
                        'Grow with \nHidden Pantry',
                        style: TextStyle(
                          color: const Color(0xFFFFF2EA),
                          fontSize: 40 * wScale,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                          fontFamily: 'Satoshi',
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    left: 52 * wScale,
                    top: 648 * hScale,
                    child: SizedBox(
                      width: 290 * wScale,
                      child: Text(
                        'Connect with health-conscious \nusers looking for personalized \nnutrition guidance .',
                        style: TextStyle(
                          color: const Color(0xFFFFF2EA),
                          fontSize: 14 * wScale,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3 * wScale,
                          fontFamily: 'Satoshi',
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    left: 26 * wScale,
                    top: 776 * hScale,
                    child: OnboardingProgressBar(
                      currentStep: 4,
                      totalSteps: 4,
                      wScale: wScale,
                    ),
                  ),

                  Positioned(
                    right: 46 * wScale,
                    top: 749 * hScale,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (_, __, ___) => LoadingFive(),
                            transitionDuration: const Duration(milliseconds: 500),
                            transitionsBuilder: (_, anim, __, child) =>
                                FadeTransition(opacity: anim, child: child),
                          ),
                        );
                      },
                      child: Image.asset(
                        'assets/icons/next_button.png',
                        width: 40 * wScale,
                        height: 27 * hScale,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
