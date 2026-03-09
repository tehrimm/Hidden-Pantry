import 'package:flutter/material.dart';
import 'loading_one.dart'; // Ensure OnboardingProgressBar is available
import 'loading_two.dart';
import 'loading_four.dart';

class LoadingThree extends StatelessWidget {
  const LoadingThree({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // prevent app from closing
      onPopInvokedWithResult: (didPop, result) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const LoadingTwo(),
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
                          'assets/bg/3.jpg',
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
                        'assets/Logos/logo.png',
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

                  Positioned(
                    left: 52 * wScale,
                    top: 648 * hScale,
                    child: SizedBox(
                      width: 290 * wScale,
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

                  Positioned(
                    left: 26 * wScale,
                    top: 776 * hScale,
                    child: OnboardingProgressBar(
                      currentStep: 3,
                      totalSteps: 4,
                      wScale: wScale,
                    ),
                  ),

                  Positioned(
                    right: 46 * wScale,
                    top: 749 * hScale,
                    child: GestureDetector(
                      onTap: () async {
                        // Preload the next screen's heavy asset before animating
                        await precacheImage(const AssetImage('assets/bg/6.png'), context);
                        if (!context.mounted) return;
                        
                        Navigator.pushReplacement(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (_, __, ___) => const LoadingFour(),
                            transitionDuration: const Duration(milliseconds: 500),
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
