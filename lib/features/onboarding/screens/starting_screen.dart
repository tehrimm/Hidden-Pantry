// lib/screens/starting_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'loading_one.dart'; // exports LoadingOne
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hidden_pantry_app/features/auth/screens/nutritionist_signup_wrapper.dart';
import 'package:hidden_pantry_app/core/widgets/main_navigation_shell.dart';



class StartingScreen extends StatefulWidget {
  const StartingScreen({super.key});

  @override
  State<StartingScreen> createState() => _StartingScreenState();
}

class _StartingScreenState extends State<StartingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _rotateCtrl; // dots rotation (infinite)
  late final AnimationController _knifeCtrl;  // knife entrance (once)

  late final Animation<double> _knifeX;
  late final Animation<double> _knifeY;

  Timer? _navTimer;

  @override
  void initState() {
    
    super.initState();

     // Hide system navigation & status bars
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );


    // Dots rotation -> 6 seconds
    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    // Knife entrance animation
    _knifeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Knife comes from TOP-RIGHT (off-screen) to target 80x335
    _knifeX = Tween<double>(
      begin: 420, // off-screen right
      end: 80,    // final left
    ).animate(CurvedAnimation(parent: _knifeCtrl, curve: Curves.easeOutCubic));

    _knifeY = Tween<double>(
      begin: -140, // off-screen top
      end: 280,    // final top
    ).animate(CurvedAnimation(parent: _knifeCtrl, curve: Curves.easeOutCubic));

    // Start knife AFTER 2 seconds
Future.delayed(const Duration(seconds: 1), () {
  if (mounted) {
    _knifeCtrl.forward();
  }
});


    // After 6 seconds -> Check Session -> Home OR LoadingOne
    _navTimer = Timer(const Duration(seconds: 4), () async {
      if (!mounted) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Check if user is a nutritionist
        bool isNutritionist = false;
        try {
          final doc = await FirebaseFirestore.instance
              .collection('nutritionists')
              .doc(user.uid)
              .get();
          isNutritionist = doc.exists && doc.data()?['verificationStatus'] != null;
        } catch (e) {
          debugPrint("Error checking nutritionist status: $e");
        }

        if (!mounted) return;

        if (isNutritionist) {
           // Nutritionist -> Go to Wrapper (handles pending/approved)
           Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const NutritionistSignupWrapper()),
          );
        } else {
          // Regular User -> Go to Main Shell (was HomeScreen)
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainNavigationShell()),
          );
        }
      } else {
        // No user -> Go LoadingOne
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoadingOne()),
        );
      }
    });
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _rotateCtrl.dispose();
    _knifeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold stays, but background is the same gradient (no white edges)
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF3EB), Color(0xFFF6DFD1)],
            stops: [0.42, 1],
          ),
        ),
        child: Center(
          child: Container(
            width: 393,
            height: 852,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              // optional: keep it transparent since background already gradient
              // color: Colors.transparent,
            ),
            child: Stack(
              children: [
                // Background rings + rotating dots
                PatternBackground(rotation: _rotateCtrl),

                // Knife BEHIND name
                AnimatedBuilder(
                  animation: _knifeCtrl,
                  builder: (context, _) {
                    return Positioned(
                      left: _knifeX.value,
                      top: _knifeY.value,
                      child: Transform.rotate(
                        angle: 4 * math.pi / 180, // -10 degrees
                        child: Image.asset(
                          'assets/Logos/knife.png',
                          width: 253,
                          height: 210,
                          fit: BoxFit.contain,
                        ),
                      ),
                    );
                  },
                ),

                // Name on TOP of knife
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 365, // keep your chosen position
                  child: Center(child: _LogoText()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ------------------------------
/// Pattern Background
/// ------------------------------
class PatternBackground extends StatelessWidget {
  final Animation<double> rotation;
  const PatternBackground({super.key, required this.rotation});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 393,
      height: 852,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFF3EB), Color(0xFFF6DFD1)],
          stops: [0.42, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned(left: -101, top: 248, child: _ring(w: 372, h: 351, rx: 186, ry: 176)),
          Positioned(left: -298, top: 189, child: _ring(w: 633, h: 470, rx: 317, ry: 235)),
          Positioned(left: -707, top: 54, child: _ring(w: 1111, h: 745, rx: 556, ry: 373)),
          Positioned(left: -707, top: -282, child: _ring(w: 1192, h: 1211, rx: 596, ry: 606)),

          // Rotating dots group
          AnimatedBuilder(
            animation: rotation,
            // ignore: unnecessary_underscores
            builder: (_, __) {
              final angle = rotation.value * 2 * math.pi;
              return Transform.rotate(
                angle: angle,
                alignment: Alignment.center,
                child: Stack(
                  children: const [
                    Positioned(left: 284, top: 219, child: _Dot(Color(0xFF8C308E))),
                    Positioned(left: 67, top: 510, child: _Dot(Color(0xFFE18F5F))),
                    Positioned(left: 249, top: 620, child: _Dot(Color(0xFFB44944))),
                    Positioned(left: 85, top: 99, child: _Dot(Color(0xFF5797C0))),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _ring({
    required double w,
    required double h,
    required double rx,
    required double ry,
  }) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        border: Border.all(width: 2, color: const Color(0xFFF5DDCE)),
        borderRadius: BorderRadius.all(Radius.elliptical(rx, ry)),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot(this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }
}

/// ------------------------------
/// Logo Text
/// ------------------------------
class _LogoText extends StatelessWidget {
  const _LogoText();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/Logos/name.png',
      width: 258,
      height: 115,
      fit: BoxFit.contain,
    );
  }
}



