import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hidden_pantry_app/features/onboarding/screens/starting_screen.dart';

class SuspendedScreen extends StatelessWidget {
  final DateTime suspendedUntil;
  const SuspendedScreen({super.key, required this.suspendedUntil});

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    final purple = const Color(0xFF462F4D);
    final orange = const Color(0xFFF2894F);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF3EB),
      body: Stack(
        children: [
          const PatternBackground(),
          Center(
            child: Padding(
              padding: EdgeInsets.all(30.sw),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(20.sw),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.block_flipped, color: Colors.redAccent, size: 60.sw),
                  ),
                  SizedBox(height: 30.sh),
                  Text(
                    'Account Suspended',
                    style: TextStyle(
                      color: purple,
                      fontSize: 28.sp,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Satoshi',
                    ),
                  ),
                  SizedBox(height: 16.sh),
                  Text(
                    'Your account has been temporarily suspended for violating our community guidelines.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: purple.withOpacity(0.7),
                      fontSize: 16.sp,
                      height: 1.5,
                      fontFamily: 'Satoshi',
                    ),
                  ),
                  SizedBox(height: 24.sh),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 20.sw, vertical: 12.sh),
                    decoration: BoxDecoration(
                      color: purple.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(15.sw),
                    ),
                    child: Text(
                      'Access restored on:\n${DateFormat('MMM dd, yyyy').format(suspendedUntil)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: purple,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Satoshi',
                      ),
                    ),
                  ),
                  SizedBox(height: 40.sh),
                  GestureDetector(
                    onTap: () async {
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const StartingScreen()),
                          (route) => false,
                        );
                      }
                    },
                    child: Container(
                      width: 200.sw,
                      height: 60.sh,
                      decoration: BoxDecoration(
                        color: orange,
                        borderRadius: BorderRadius.circular(20.sw),
                        boxShadow: [
                          BoxShadow(
                            color: orange.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'Logout',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Satoshi',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
