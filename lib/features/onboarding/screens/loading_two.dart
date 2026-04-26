import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'loading_one.dart';
import 'loading_three.dart';

class LoadingTwo extends StatelessWidget {
  const LoadingTwo({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // prevent app from closing
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const LoadingOne(),
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
                  // Background Gradient
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFFF3EB), Color(0xFFF6DFD1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        stops: [0.4, 1.0],
                      ),
                    ),
                  ),

                  // Decorative Orbs
                  const _OnboardingBackgroundPattern(),

                  // Big card image
                  Positioned(
                    left: 26 * wScale,
                    top: 34 * hScale,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(40),
                      child: SizedBox(
                        width: 341 * wScale,
                        height: 788 * hScale,
                        child: Image.asset(
                          'assets/bg/2.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),

                  // Top logo (center)
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

                  // Title
                  Positioned(
                    left: 52 * wScale,
                    top: 555 * hScale,
                    child: SizedBox(
                      width: 330 * wScale,
                      child: Text(
                        'Learn to\nCook',
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

                  // Subtext
                  Positioned(
                    left: 52 * wScale,
                    top: 648 * hScale,
                    child: SizedBox(
                      width: 290 * wScale,
                      child: Text(
                        'Master new dishes with clear, \nguided instructions.',
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

                  // Progress bar (4 states) -> currentStep: 2
                  Positioned(
                    left: 26 * wScale,
                    top: 776 * hScale,
                    child: OnboardingProgressBar(
                      currentStep: 2,
                      totalSteps: 4,
                      wScale: wScale,
                    ),
                  ),

                  // Next button
                  Positioned(
                    right: 46 * wScale, // Adjusted from left: 307
                    top: 749 * hScale,
                    child: GestureDetector(
                      onTap: () async {
                        // Preload the next screen's heavy asset before animating
                        await precacheImage(const AssetImage('assets/bg/3.jpg'), context);
                        if (!context.mounted) return;
                        
                        Navigator.pushReplacement(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (_, __, ___) => const LoadingThree(),
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

class _OnboardingBackgroundPattern extends StatelessWidget {
  const _OnboardingBackgroundPattern();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: _OnboardingFloatingOrb(
              color: const Color(0xFFFFE0D3).withValues(alpha: 0.5),
              size: 400,
              duration: const Duration(seconds: 15),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -150,
            child: _OnboardingFloatingOrb(
              color: const Color(0xFFEF8A54).withValues(alpha: 0.1),
              size: 500,
              duration: const Duration(seconds: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingFloatingOrb extends StatefulWidget {
  final Color color;
  final double size;
  final Duration duration;

  const _OnboardingFloatingOrb({required this.color, required this.size, required this.duration});

  @override
  State<_OnboardingFloatingOrb> createState() => _OnboardingFloatingOrbState();
}

class _OnboardingFloatingOrbState extends State<_OnboardingFloatingOrb> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    
    bool isTest = WidgetsBinding.instance.runtimeType.toString().contains('TestWidgetsFlutterBinding');
    if (!isTest) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double angle = _controller.value * 2 * math.pi;
        return Transform.translate(
          offset: Offset(math.cos(angle) * 30, math.sin(angle) * 50),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [widget.color, widget.color.withValues(alpha: 0)],
              ),
            ),
          ),
        );
      },
    );
  }
}

