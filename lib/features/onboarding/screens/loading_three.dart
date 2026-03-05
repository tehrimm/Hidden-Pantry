import 'package:flutter/material.dart';
import 'loading_two.dart';
import 'loading_four.dart';

class LoadingThree extends StatelessWidget {
  const LoadingThree({super.key});

  @override
  Widget build(BuildContext context) {
return PopScope(
  canPop: false, // prevent app from closing
  onPopInvokedWithResult: (didPop, result) {
    if (didPop) return;


    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoadingTwo(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      ),
    );
  },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF3EB),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final double screenWidth = constraints.maxWidth;
            final double screenHeight = constraints.maxHeight;

            // Design dimensions
            const double designWidth = 393.0;
            const double designHeight = 852.0;

            // Scale factors
            final double wScale = screenWidth / designWidth;
            final double hScale = screenHeight / designHeight;

            return SizedBox(
              width: screenWidth,
              height: screenHeight,
              child: Stack(
                children: [
                  // Background Image
                  Positioned(
                    left: 26 * wScale,
                    top: 34 * hScale,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(40),
                      child: SizedBox(
                        width: 341 * wScale,
                        height: 788 * hScale,
                        child: Image.asset(
                          'assets/bg/3.jpg',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),

                  // Logo (Centered horizontally)
                  Positioned(
                    top: 62 * hScale,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Image.asset(
                        'assets/Logos/logo.png',
                        width: 113 * wScale,
                        height: 26 * hScale,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  // Title Text
                  Positioned(
                    left: 52 * wScale,
                    top: 555 * hScale,
                    child: SizedBox(
                      width: 330 * wScale,
                      child: Text(
                        'Scan and\nCook',
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

                  // Subtitle Text
                  Positioned(
                    left: 52 * wScale,
                    top: 648 * hScale,
                    child: SizedBox(
                      width: 260 * wScale,
                      child: Text(
                        'Turn what you have at home into \ndelicious meals.',
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

                  // Progress Bar
                  Positioned(
                    left: 26 * wScale,
                    top: 776 * hScale,
                    child: OnboardingProgressBar(
                      currentStep: 3,
                      totalSteps: 4,
                      wScale: wScale,
                    ),
                  ),

                  // Next Button
                  Positioned(
                    right: 46 * wScale, // Adjusted from left: 307
                    top: 749 * hScale,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (_, __, ___) => const LoadingFour(),
                            transitionDuration: const Duration(milliseconds: 400),
                            transitionsBuilder: (_, anim, __, child) =>
                              FadeTransition(opacity: anim, child: child),
                          ),
                        );
                      },
                      child: Image.asset(
                        'assets/icons/nextButton.png',
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

class OnboardingProgressBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final double wScale;

  const OnboardingProgressBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.wScale = 1.0,
  });

  double _filledWidth() {
    final widths = [37.5 * wScale, 75.0 * wScale, 112.5 * wScale, 150.0 * wScale];
    final idx = (currentStep - 1).clamp(0, widths.length - 1);
    return widths[idx];
  }

  @override
  Widget build(BuildContext context) {
    final baseWidth = 150.0 * wScale;
    const height = 11.0;

    return Stack(
      children: [
        Container(
          width: baseWidth,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFFF9E3D5),
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        Container(
          width: _filledWidth(),
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFFFF9453),
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ],
    );
  }
}



