import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'terms_and_condition.dart';
import 'package:hidden_pantry_app/features/auth/screens/signup_user.dart';
import 'package:hidden_pantry_app/features/auth/screens/login_user.dart';
import 'package:hidden_pantry_app/features/auth/screens/nutritionist_signup_wrapper.dart';

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
    return Scaffold(
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
              clipBehavior: Clip.none,
              children: [
                // Background Image
                Positioned(
                  left: 26 * wScale,
                  top: 28 * hScale,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(45 * wScale),
                    child: Image.asset(
                      'assets/bg/4.png',
                      width: 341 * wScale,
                      height: 562 * hScale,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                // Logo (Centered horizontally)
                Positioned(
                  top: 56 * hScale,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Image.asset(
                      'assets/Logos/logo2.png',
                      width: 113 * wScale,
                      height: 26 * hScale,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                // Question Mark Button
                Positioned(
                  right: 26 * wScale,
                  top: 43 * hScale,
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
                      width: 52 * wScale,
                      height: 52 * wScale, // Keeping it square
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5DDCE),
                        borderRadius: BorderRadius.circular(26 * wScale),
                      ),
                      child: Center(
                        child: Text(
                          '?',
                          style: TextStyle(
                            color: const Color(0xFF433020),
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
                  left: 45 * wScale,
                  top: 403 * hScale,
                  child: SizedBox(
                    width: 291 * wScale,
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
                  left: 45 * wScale,
                  top: 509 * hScale,
                  child: SizedBox(
                    width: 237 * wScale,
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
                  left: 26 * wScale,
                  top: 624 * hScale,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignupUserScreen()),
                      );
                    },
                    child: Container(
                      width: 341 * wScale,
                      height: 60 * hScale,
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
                  left: 26 * wScale,
                  top: 694 * hScale,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NutritionistSignupWrapper()),
                      );
                    },
                    child: Container(
                      width: 341 * wScale,
                      height: 60 * hScale,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9E3D5),
                        borderRadius: BorderRadius.circular(20 * wScale),
                      ),
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

                // Login Text
                Positioned(
                  left: 130 * wScale,
                  top: 771 * hScale,
                  child: Text(
                    'Have an Account?',
                    style: TextStyle(
                      color: const Color(0xFF462F4D),
                      fontSize: 12 * wScale,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Satoshi',
                    ),
                  ),
                ),
                Positioned(
                  left: 229 * wScale,
                  top: 771 * hScale,
                  child: GestureDetector(
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
                        fontSize: 12 * wScale,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Satoshi',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}



