import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'terms_and_condition.dart';
import 'package:hidden_pantry_app/features/auth/screens/signup_user.dart';
import 'package:hidden_pantry_app/features/auth/screens/login_user.dart';
import 'package:hidden_pantry_app/features/auth/screens/nutritionist_signup_wrapper.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';

class LoadingFive extends StatefulWidget {
  const LoadingFive({super.key});

  @override
  State<LoadingFive> createState() => _LoadingFiveState();
}

class _LoadingFiveState extends State<LoadingFive> {
  @override
  void initState() {
    super.initState();
    _markOnboardingSeen();
  }

  Future<void> _markOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;

    final bool isSmallScreen = screenHeight < 780;
    final bool isTablet = screenWidth >= 600;

    // Scale factors (clamped on tablets for a beautiful, premium mobile column view)
    final double wScale = isTablet ? 1.15 : (screenWidth / 393.0);
    final double hScale = isTablet ? 1.15 : (screenHeight / 852.0);

    // Stretch the card so its margin is exactly 30 logical pixels from both sides on small screens, center on tablets
    final double cardLeft = isTablet ? (screenWidth - 341 * wScale) / 2 : (isSmallScreen ? 30.0 : 26.sw);
    final double cardWidth = isTablet ? 341 * wScale : (isSmallScreen ? (screenWidth - 60.0) : 341.sw);
    // Maintain a slightly shorter height on small screens to fit all buttons and login text, but use topCenter alignment to keep top wave flawless
    final double cardHeight = isTablet ? cardWidth * 1.648 : (isSmallScreen ? 470.0 : cardWidth * 1.648);
    final double cardTop = isTablet ? 45 * hScale : (isSmallScreen ? 16 * hScale : 28.sh);
    final double cardBottom = cardTop + cardHeight;

    final double logoTop = cardTop + (isTablet ? 28 * hScale : (isSmallScreen ? 36 * hScale : 28 * hScale));
    final double logoWidth = isTablet ? 113 * wScale : (isSmallScreen ? 140 * wScale : 113.sw);
    final double logoHeight = isTablet ? 26 * hScale : (isSmallScreen ? 32 * hScale : 26.sh);

    final double questionTop = cardTop + (isSmallScreen ? 12 * hScale : 15 * hScale);
    final double questionSize = isTablet ? 52 * wScale : (isSmallScreen ? 44.sw : 52.sw);
    final double questionRight = isTablet ? screenWidth - (cardLeft + cardWidth) + 15 * wScale : 26.sw;

    // Position Title and Description dynamically relative to the bottom of the card with guaranteed zero overlap
    final double subtextTop = isSmallScreen 
        ? cardBottom - 85 * hScale 
        : cardBottom - 81 * hScale;
    final double titleTop = isSmallScreen 
        ? subtextTop - 95 * hScale 
        : subtextTop - 106 * hScale;

    // Position buttons relative to the bottom of the card, using premium heights to avoid squishing
    final double buttonHeight = isTablet ? 60 * hScale : (isSmallScreen ? 52.0 : 60.sh);
    final double homecookTop = cardBottom + (isTablet ? 34 * hScale : (isSmallScreen ? 14 * hScale : 34 * hScale));
    final double nutritionistTop = homecookTop + buttonHeight + (isTablet ? 10 * hScale : (isSmallScreen ? 10 * hScale : 10.sh));
    final double loginTop = nutritionistTop + buttonHeight + (isTablet ? 15 * hScale : (isSmallScreen ? 15 * hScale : 17.sh));

    final double buttonLeft = isTablet ? cardLeft : (isSmallScreen ? 30.0 : 26.sw);
    final double buttonWidth = isTablet ? cardWidth : (isSmallScreen ? (screenWidth - 60.0) : 341.sw);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF3EB),
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          clipBehavior: Clip.none,
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

                // Background Image
                Positioned(
                  left: cardLeft,
                  top: cardTop,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(45.sw),
                    child: SizedBox(
                      width: cardWidth,
                      height: cardHeight,
                      child: Image.asset(
                        'assets/bg/4.png',
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                      ),
                    ),
                  ),
                ),

                // Logo (Centered horizontally)
                Positioned(
                  top: logoTop,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Image.asset(
                      'assets/logos/logo2.png',
                      width: logoWidth,
                      height: logoHeight,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                // Question Mark Button
                Positioned(
                  right: questionRight,
                  top: questionTop,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TermsAndConditionScreen(viewOnly: true),
                        ),
                      );
                    },
                    child: Container(
                      width: questionSize,
                      height: questionSize, // Keeping it square
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5DDCE),
                        borderRadius: BorderRadius.circular(questionSize / 2),
                      ),
                      child: Center(
                        child: Text(
                          '?',
                          style: TextStyle(
                            color: const Color(0xFF462F4D),
                            fontSize: 20 * wScale,
                            fontFamily: 'Satoshi',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Title Text
                Positioned(
                  left: cardLeft + 26 * wScale,
                  top: titleTop,
                  child: SizedBox(
                    width: cardWidth - 50 * wScale,
                    child: Text(
                      'Create an\nAccount',
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
                  left: cardLeft + 26 * wScale,
                  top: subtextTop,
                  child: SizedBox(
                    width: cardWidth - 52 * wScale,
                    child: Text(
                      'Create an account as a home cook\nor a professional nutritionist',
                      style: TextStyle(
                        color: const Color(0xFFFFF2EA),
                        fontSize: 14 * wScale,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3 * wScale,
                        fontFamily: 'Satoshi',
                      ),
                    ),
                  ),
                ),

                // Register Homecook Button
                Positioned(
                  left: buttonLeft,
                  top: homecookTop,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignupUserScreen()),
                      );
                    },
                    child: Container(
                      width: buttonWidth,
                      height: buttonHeight,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2894F),
                        borderRadius: BorderRadius.circular(20 * wScale),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/icons/chef.png',
                            width: 24 * wScale,
                            height: 24 * wScale,
                            fit: BoxFit.contain,
                          ),
                          SizedBox(width: 12 * wScale),
                          Text(
                            'Register as Homecook',
                            style: TextStyle(
                              color: const Color(0xFFFFF2EA),
                              fontSize: 14 * wScale,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3 * wScale,
                              fontFamily: 'Satoshi',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Register Nutritionist Button
                Positioned(
                  left: buttonLeft,
                  top: nutritionistTop,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NutritionistSignupWrapper()),
                      );
                    },
                    child: Container(
                      width: buttonWidth,
                      height: buttonHeight,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9E3D5),
                        borderRadius: BorderRadius.circular(20 * wScale),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/icons/apple.png',
                              width: 24 * wScale,
                              height: 24 * wScale,
                              fit: BoxFit.contain,
                            ),
                            SizedBox(width: 12 * wScale),
                            Text(
                              'Register as Nutritionist',
                              style: TextStyle(
                                color: const Color(0xFFF2894F),
                                fontSize: 14 * wScale,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3 * wScale,
                                fontFamily: 'Satoshi',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Login Text
                Positioned(
                  left: 0,
                  right: 0,
                  top: loginTop,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Have an Account? ',
                        style: TextStyle(
                          color: const Color(0xFF462F4D),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Satoshi',
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const UserLoginScreen()),
                          );
                        },
                        child: Text(
                          'Login',
                          style: TextStyle(
                            color: const Color(0xFF462F4D),
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Satoshi',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
            top: -100.sh,
            right: -100.sw,
            child: _OnboardingFloatingOrb(
              color: const Color(0xFFFFE0D3).withValues(alpha: 0.5),
              size: 400,
              duration: const Duration(seconds: 15),
            ),
          ),
          Positioned(
            bottom: 100.sh,
            left: -150.sw,
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
            width: widget.size.sw,
            height: widget.size.sw,
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



