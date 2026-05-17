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

            final bool isTablet = screenWidth >= 600;

            // Scale factors (clamped on tablets for a beautiful, premium mobile column view)
            final double wScale = isTablet ? 1.15 : (screenWidth / designWidth);
            final double hScale = isTablet ? 1.15 : (screenHeight / designHeight);

            final bool isSmallScreen = screenHeight < 780;

            final double cardWidth = 341 * wScale;
            final double cardHeight = 788 * hScale;
            final double cardTop = isTablet ? (screenHeight - cardHeight) / 2 - 10 : 34 * hScale;
            final double cardLeft = isTablet ? (screenWidth - cardWidth) / 2 : 26 * wScale;

            final double logoTop = isTablet ? cardTop + 45 * hScale : 62 * hScale;

            // Position all key interactive elements relative to the bottom of the card container
            final double progressBarTop = isSmallScreen 
                ? cardTop + cardHeight - 58 * hScale 
                : cardTop + cardHeight - 46 * hScale;
            final double progressBarLeft = isTablet
                ? cardLeft + 26 * wScale
                : (isSmallScreen ? 38 * wScale : 26 * wScale);

            final double nextButtonTop = cardTop + cardHeight - 73 * hScale;
            final double nextButtonRight = isTablet
                ? screenWidth - (cardLeft + cardWidth) + 20 * wScale
                : 46 * wScale;

            // Shift texts higher up on small screens to prevent overlap while maintaining exact scale mapping
            final double titleTop = isSmallScreen 
                ? cardTop + cardHeight - 330 * hScale 
                : cardTop + cardHeight - 267 * hScale;
            final double subtextTop = isSmallScreen 
                ? cardTop + cardHeight - 200 * hScale 
                : cardTop + cardHeight - 174 * hScale;

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
                    left: cardLeft,
                    top: cardTop,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(40),
                      child: SizedBox(
                        width: cardWidth,
                        height: cardHeight,
                        child: Image.asset(
                          'assets/bg/2.png',
                          fit: BoxFit.cover,
                          alignment: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),

                  // Top logo (center)
                  Positioned(
                    top: logoTop,
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
                    left: cardLeft + 26 * wScale,
                    top: titleTop,
                    child: SizedBox(
                      width: cardWidth - 50 * wScale,
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
                    left: cardLeft + 26 * wScale,
                    top: subtextTop,
                    child: SizedBox(
                      width: cardWidth - 81 * wScale,
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
                    left: progressBarLeft,
                    top: progressBarTop,
                    child: OnboardingProgressBar(
                      currentStep: 2,
                      totalSteps: 4,
                      wScale: wScale,
                    ),
                  ),

                  // Next button
                  Positioned(
                    right: nextButtonRight,
                    top: nextButtonTop,
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

