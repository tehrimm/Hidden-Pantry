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
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';
import 'loading_five.dart';
import 'package:hidden_pantry_app/features/auth/screens/suspended_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hidden_pantry_app/core/services/view_mode_service.dart';



class StartingScreen extends StatefulWidget {
  final FirebaseFirestore? firestore;
  final SharedPreferences? prefs;
  const StartingScreen({super.key, this.firestore, this.prefs});

  @override
  State<StartingScreen> createState() => _StartingScreenState();
}

class _StartingScreenState extends State<StartingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _rotateCtrl;
  late final AnimationController _knifeCtrl;

  // Not final — set in didChangeDependencies after init() is called
  late Animation<double> _knifeX;
  late Animation<double> _knifeY;

  bool _animationsInitialized = false;
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();
    debugPrint('[StartingScreen] initState - App Start / Splash');

    // Dots rotation -> 6 seconds
    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    
    // Disable repeat in tests to prevent pumpAndSettle timeouts
    bool isTest = WidgetsBinding.instance.runtimeType.toString().contains('TestWidgetsFlutterBinding');
    if (!isTest) {
      _rotateCtrl.repeat();
    }

    // Knife entrance controller only — tweens set in didChangeDependencies
    _knifeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // After 4 seconds -> Check Session -> Home OR LoadingOne
    _navTimer = Timer(const Duration(seconds: 4), () async {
      debugPrint('[StartingScreen] Timer elapsed - checking auth state');
      if (!mounted) return;

      // Safely grab the current user directly rather than waiting on the stream
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // 🛑 Check for suspension first
        try {
          final userDoc = await (widget.firestore ?? FirebaseFirestore.instance)
              .collection('users')
              .doc(user.uid)
              .get();
          
          if (userDoc.exists) {
            final suspendedUntil = (userDoc.data()?['suspendedUntil'] as Timestamp?)?.toDate();
            if (suspendedUntil != null && suspendedUntil.isAfter(DateTime.now())) {
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => SuspendedScreen(suspendedUntil: suspendedUntil)),
                );
                return;
              }
            }
          }
        } catch (e) {
          debugPrint("Error checking suspension status: $e");
        }

        bool isNutritionist = false;
        try {
          final doc = await (widget.firestore ?? FirebaseFirestore.instance)
              .collection('nutritionists')
              .doc(user.uid)
              .get();
          isNutritionist = doc.exists && doc.data()?['verificationStatus'] != null;
          
          // Check nutritionist suspension if they have a separate doc
          if (isNutritionist) {
             final suspendedUntil = (doc.data()?['suspendedUntil'] as Timestamp?)?.toDate();
             if (suspendedUntil != null && suspendedUntil.isAfter(DateTime.now())) {
               if (mounted) {
                 Navigator.of(context).pushReplacement(
                   MaterialPageRoute(builder: (_) => SuspendedScreen(suspendedUntil: suspendedUntil)),
                 );
                 return;
               }
             }
          }
        } catch (e) {
          debugPrint("Error checking nutritionist status: $e");
        }

        if (!mounted) return;

        if (isNutritionist) {
          final inUserView = await ViewModeService().isInUserView();
          if (mounted) {
            if (inUserView) {
              debugPrint('[StartingScreen] Nutritionist in User View - navigating to MainNavigationShell');
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => MainNavigationShell()),
              );
            } else {
              debugPrint('[StartingScreen] Nutritionist in Dashboard View - navigating to Wrapper');
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => NutritionistSignupWrapper()),
              );
            }
          }
        } else {
          debugPrint('[StartingScreen] Regular user - navigating to MainNavigationShell');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => MainNavigationShell()),
          );
        }
      } else {
        debugPrint('[StartingScreen] No user found - checking if onboarding seen');
        final prefs = widget.prefs ?? await SharedPreferences.getInstance();
        final seenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

        if (!mounted) return;

        if (seenOnboarding) {
          debugPrint('[StartingScreen] Onboarding seen - navigating to LoadingFive');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoadingFive()),
          );
        } else {
          debugPrint('[StartingScreen] Onboarding NOT seen - navigating to LoadingOne');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoadingOne()),
          );
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_animationsInitialized) return;
    _animationsInitialized = true;

    // Init responsive utils here so .sw/.sh are correct for the real device
    ResponsiveUtils.init(context);

    // Knife comes from TOP-RIGHT (off-screen) to target
    _knifeX = Tween<double>(
      begin: 420.sw, // off-screen right
      end: 80.sw,    // final left
    ).animate(CurvedAnimation(parent: _knifeCtrl, curve: Curves.easeOutCubic));

    _knifeY = Tween<double>(
      begin: (-140).sh, // off-screen top
      end: 280.sh,      // final top
    ).animate(CurvedAnimation(parent: _knifeCtrl, curve: Curves.easeOutCubic));

    // Start knife quickly to prevent laggy perception
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _knifeCtrl.forward();
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
    ResponsiveUtils.init(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF3EB), Color(0xFFF6DFD1)],
            stops: [0.42, 1],
          ),
        ),
        child: Stack(
          children: [
            // Background rings + rotating dots
            SplashPatternBackground(rotation: _rotateCtrl),

            // Knife BEHIND name
            AnimatedBuilder(
              animation: _knifeCtrl,
              builder: (context, _) {
                return Positioned(
                  left: _knifeX.value,
                  top: _knifeY.value,
                  child: Transform.rotate(
                    angle: 4 * math.pi / 180,
                    child: Image.asset(
                      'assets/logos/knife.png',
                      width: 253.sw,
                      height: 210.sw,
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),

            // Name on TOP of knife
            Positioned(
              left: 0,
              right: 0,
              top: 365.sh,
              child: const Center(child: _LogoText()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Splash Pattern Background
/// ------------------------------
class SplashPatternBackground extends StatelessWidget {
  final Animation<double> rotation;
  const SplashPatternBackground({super.key, required this.rotation});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFF3EB), Color(0xFFF6DFD1)],
          stops: [0.42, 1],
        ),
      ),
      child: Stack(
        children: [
          // Dynamic Floating Orbs
          const _SplashBackgroundPattern(),

          Positioned(left: -101.sw, top: 248.sh, child: _ring(w: 372.sw, h: 351.sh, rx: 186.sw, ry: 176.sh)),
          Positioned(left: -298.sw, top: 189.sh, child: _ring(w: 633.sw, h: 470.sh, rx: 317.sw, ry: 235.sh)),
          Positioned(left: -707.sw, top: 54.sh, child: _ring(w: 1111.sw, h: 745.sh, rx: 556.sw, ry: 373.sh)),
          Positioned(left: -707.sw, top: -282.sh, child: _ring(w: 1192.sw, h: 1211.sh, rx: 596.sw, ry: 606.sh)),

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
                  children: [
                    Positioned(left: 284.sw, top: 219.sh, child: _Dot(const Color(0xFF8C308E))),
                    Positioned(left: 67.sw, top: 510.sh, child: _Dot(const Color(0xFFE18F5F))),
                    Positioned(left: 249.sw, top: 620.sh, child: _Dot(const Color(0xFFB44944))),
                    Positioned(left: 85.sw, top: 99.sh, child: _Dot(const Color(0xFF5797C0))),
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
        border: Border.all(width: 2.sw, color: const Color(0xFFF5DDCE)),
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
      width: 10.sw,
      height: 10.sw,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5.sw),
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
      'assets/logos/name.png',
      width: 258.sw,
      height: 115.sh,
      fit: BoxFit.contain,
    );
  }
}

class _SplashBackgroundPattern extends StatelessWidget {
  const _SplashBackgroundPattern();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -100.sh,
            right: -100.sw,
            child: _SplashFloatingOrb(
              color: const Color(0xFFFFE0D3).withValues(alpha: 0.5),
              size: 400,
              duration: const Duration(seconds: 15),
            ),
          ),
          Positioned(
            bottom: 100.sh,
            left: -150.sw,
            child: _SplashFloatingOrb(
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

class _SplashFloatingOrb extends StatefulWidget {
  final Color color;
  final double size;
  final Duration duration;

  const _SplashFloatingOrb({required this.color, required this.size, required this.duration});

  @override
  State<_SplashFloatingOrb> createState() => _SplashFloatingOrbState();
}

class _SplashFloatingOrbState extends State<_SplashFloatingOrb> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    
    // Disable repeat in tests to prevent pumpAndSettle timeouts
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
