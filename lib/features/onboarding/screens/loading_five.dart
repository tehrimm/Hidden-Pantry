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
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3EB),
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
                // Background Image
                Positioned(
                  left: 26.sw,
                  top: 28.sh,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(45.sw),
                    child: Image.asset(
                      'assets/bg/4.png',
                      width: 341.sw,
                      height: 562.sh,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                // Logo (Centered horizontally)
                Positioned(
                  top: 56.sh,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Image.asset(
                      'assets/logos/logo2.png',
                      width: 113.sw,
                      height: 26.sh,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                // Question Mark Button
                Positioned(
                  right: 26.sw,
                  top: 43.sh,
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
                      width: 52.sw,
                      height: 52.sw, // Keeping it square
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5DDCE),
                        borderRadius: BorderRadius.circular(26.sw),
                      ),
                      child: Center(
                        child: Text(
                          '?',
                          style: TextStyle(
                            color: const Color(0xFF433020),
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
                  left: 45.sw,
                  top: 403.sh,
                  child: SizedBox(
                    width: 291.sw,
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
                  left: 45.sw,
                  top: 509.sh,
                  child: SizedBox(
                    width: 237.sw,
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
                  top: 624.sh,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignupUserScreen()),
                      );
                    },
                    child: Container(
                      width: 341.sw,
                      height: 60.sh,
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
                  top: 694.sh,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NutritionistSignupWrapper()),
                      );
                    },
                    child: Container(
                      width: 341.sw,
                      height: 60.sh,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9E3D5),
                        borderRadius: BorderRadius.circular(20.sw),
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
                  left: 130.sw,
                  top: 771.sh,
                  child: Text(
                    'Have an Account?',
                    style: TextStyle(
                      color: const Color(0xFF462F4D),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Satoshi',
                    ),
                  ),
                ),
                Positioned(
                  left: 229.sw,
                  top: 771.sh,
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
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Satoshi',
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



