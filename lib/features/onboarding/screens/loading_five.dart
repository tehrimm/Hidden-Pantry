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
    final double hScale = screenHeight / 852.0;
    final double wScale = screenWidth / 393.0;

    final bool isSmallScreen = screenHeight < 780;

    // Stretch the card so its margin is exactly 30 logical pixels from both sides
    final double cardLeft = isSmallScreen ? 30.0 : 26.sw;
    final double cardWidth = isSmallScreen ? (screenWidth - 60.0) : 341.sw;
    // Maintain a slightly shorter height on small screens to fit all buttons and login text, but use topCenter alignment to keep top wave flawless
    final double cardHeight = isSmallScreen ? 470.0 : cardWidth * 1.648;
    final double cardTop = isSmallScreen ? 16 * hScale : 28.sh;
    final double cardBottom = cardTop + cardHeight;

    final double logoTop = cardTop + (isSmallScreen ? 36 * hScale : 28 * hScale);
    final double logoWidth = isSmallScreen ? 140 * wScale : 113.sw;
    final double logoHeight = isSmallScreen ? 32 * hScale : 26.sh;

    final double questionTop = cardTop + (isSmallScreen ? 12 * hScale : 15 * hScale);
    final double questionSize = isSmallScreen ? 44.sw : 52.sw;

    // Position Title and Description dynamically relative to the bottom of the card with guaranteed zero overlap
    final double subtextTop = isSmallScreen 
        ? cardBottom - 85 * hScale 
        : cardBottom - 81 * hScale;
    final double titleTop = isSmallScreen 
        ? subtextTop - 95 * hScale 
        : subtextTop - 106 * hScale;

    // Position buttons relative to the bottom of the card, using premium heights to avoid squishing
    final double buttonHeight = isSmallScreen ? 52.0 : 60.sh;
    final double homecookTop = cardBottom + (isSmallScreen ? 14 * hScale : 34 * hScale);
    final double nutritionistTop = homecookTop + buttonHeight + (isSmallScreen ? 10 * hScale : 10.sh);
    final double loginTop = nutritionistTop + buttonHeight + (isSmallScreen ? 15 * hScale : 17.sh);

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
                  right: 26.sw,
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
                            fontSize: 20.sp,
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
                  left: cardLeft + (isSmallScreen ? 20.sw : 19.sw),
                  top: titleTop,
                  child: SizedBox(
                    width: cardWidth - (isSmallScreen ? 40.sw : 50.sw),
                    child: Text(
                      'Create an\nAccount',
                      style: TextStyle(
                        color: const Color(0xFFFFF2EA),
                        fontSize: 40.sp,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        fontFamily: 'Satoshi',
                      ),
                    ),
                  ),
                ),

                // Subtitle Text
                Positioned(
                  left: cardLeft + (isSmallScreen ? 20.sw : 19.sw),
                  top: subtextTop,
                  child: SizedBox(
                    width: cardWidth - (isSmallScreen ? 40.sw : 104.sw),
                    child: Text(
                      'Create an account as a home cook\nor a professional nutritionist',
                      style: TextStyle(
                        color: const Color(0xFFFFF2EA),
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3.sw,
                        fontFamily: 'Satoshi',
                      ),
                    ),
                  ),
                ),

                // Register Homecook Button
                Positioned(
                  left: 26.sw,
                  top: homecookTop,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignupUserScreen()),
                      );
                    },
                    child: Container(
                      width: 341.sw,
                      height: buttonHeight,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2894F),
                        borderRadius: BorderRadius.circular(20.sw),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/icons/chef.png',
                            width: 24.sw,
                            height: 24.sw,
                            fit: BoxFit.contain,
                          ),
                          SizedBox(width: 12.sw),
                          Text(
                            'Register as Homecook',
                            style: TextStyle(
                              color: const Color(0xFFFFF2EA),
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3.sw,
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
                  left: 26.sw,
                  top: nutritionistTop,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NutritionistSignupWrapper()),
                      );
                    },
                    child: Container(
                      width: 341.sw,
                      height: buttonHeight,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9E3D5),
                        borderRadius: BorderRadius.circular(20.sw),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/icons/apple.png',
                              width: 24.sw,
                              height: 24.sw,
                              fit: BoxFit.contain,
                            ),
                            SizedBox(width: 12.sw),
                            Text(
                              'Register as Nutritionist',
                              style: TextStyle(
                                color: const Color(0xFFF2894F),
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3.sw,
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



