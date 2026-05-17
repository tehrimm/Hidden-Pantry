import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'login_user.dart'; 
import 'forget_password_email.dart';
import 'forget_password_phone.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';


class ForgetPasswordScreen extends StatefulWidget {
  const ForgetPasswordScreen({super.key});

  @override
  State<ForgetPasswordScreen> createState() => _ForgetPasswordScreenState();
}

class _ForgetPasswordScreenState extends State<ForgetPasswordScreen> with TickerProviderStateMixin {
  // 0 = email, 1 = phone
  int _selected = 0;

  // UI colors
  static const Color bg = Color(0xFFFFF3EB);
  static const Color purple = Color(0xFF462F4D);
  static const Color orange = Color(0xFFF2894F);
  static const Color btnText = Color(0xFFFFF2EA);

  // Animations
  late AnimationController _mainController;
  late List<Animation<double>> _staggeredAnimations;

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _staggeredAnimations = List.generate(
      6,
      (index) => CurvedAnimation(
        parent: _mainController,
        curve: Interval(
          0.1 + (index * 0.1),
          0.6 + (index * 0.05),
          curve: Curves.easeOutQuart,
        ),
      ),
    );

    _mainController.forward();
  }

  @override
  void dispose() {
    _mainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    final mq = MediaQuery.of(context);
    final bool isTablet = mq.size.width >= 600;
    final topPad = mq.padding.top;

    return Scaffold(
      backgroundColor: bg,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            // 1. Background Gradient (Fixed)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFF3EB), Color(0xFFF6DFD1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: [0.4, 1.0],
                  ),
                ),
              ),
            ),

            // 2. Decorative Patterns (Fixed)
            const Positioned.fill(child: _AuthBackgroundPattern()),
            const Positioned.fill(child: PatternBackground()),

            // 3. Content
            Column(
              children: [
                _AnimatedWrapper(
                  animation: _staggeredAnimations[0],
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(30.sw, topPad + (isTablet ? 24.sh : 35.sh), 30.sw, 20.sh),
                    child: Row(
                      children: [
                        BackButtonWidget(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const UserLoginScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.only(
                      left: 30.sw,
                      right: 30.sw,
                      bottom: 22.sh,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 18.sh),
                        _AnimatedWrapper(
                          animation: _staggeredAnimations[1],
                          child: SizedBox(
                            width: 260.sw,
                            child: Text(
                              "Verification Method",
                              style: TextStyle(
                                color: purple,
                                fontSize: 40.sp,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                                fontFamily: "Satoshi",
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 12.sh),
                        _AnimatedWrapper(
                          animation: _staggeredAnimations[2],
                          child: SizedBox(
                            width: 280.sw,
                            child: Text(
                              "Choose one way where you want us to send an OTP",
                              style: TextStyle(
                                color: purple,
                                fontSize: 15.sp,
                                fontFamily: "Satoshi",
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 28.sh),
                        _AnimatedWrapper(
                          animation: _staggeredAnimations[3],
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                child: _OptionCard(
                                  title: "Email",
                                  subtitle: "your@email.com",
                                  icon: Image.asset(
                                    "assets/icons/gmail.png",
                                    width: 18.sw,
                                    height: 18.sw,
                                    fit: BoxFit.contain,
                                  ),
                                  selected: _selected == 0,
                                  onTap: () => setState(() => _selected = 0),
                                ),
                              ),
                              SizedBox(width: 16.sw),
                              Expanded(
                                child: _OptionCard(
                                  title: "Phone",
                                  subtitle: "+Areacode \nXXX XXXXXXX",
                                  icon: Icon(
                                    Icons.phone_in_talk_rounded,
                                    size: 18.sw,
                                    color: Colors.white,
                                  ),
                                  selected: _selected == 1,
                                  onTap: () => setState(() => _selected = 1),
                                ),
                              ),
                            ],
                          ),
                          ),
                        ),
                        SizedBox(height: 40.sh),
                        _AnimatedWrapper(
                          animation: _staggeredAnimations[4],
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: () {
                                if (_selected == 0) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const ForgetPasswordEmailScreen(),
                                    ),
                                  );
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const ForgetPasswordPhoneScreen(),
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                width: 221.sw,
                                height: 62.sh,
                                decoration: BoxDecoration(
                                  color: orange,
                                  borderRadius: BorderRadius.circular(20.sw),
                                  boxShadow: [
                                    BoxShadow(
                                      color: orange.withValues(alpha: 0.3),
                                      blurRadius: 15,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Next",
                                      style: TextStyle(
                                        color: btnText,
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: "Satoshi",
                                      ),
                                    ),
                                    SizedBox(width: 8.sw),
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 12.sp,
                                      color: btnText,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 14.sh),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedWrapper extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  const _AnimatedWrapper({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - animation.value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _OptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget icon;
  final bool selected;
  final VoidCallback onTap;

  const _OptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  static const Color orange = Color(0xFFF2894F);
  static const Color brown = Color(0xFF74503C);
  static const Color selectRing = Color(0xFF462F4D);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30.sw),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            decoration: BoxDecoration(
              color: selected 
                  ? const Color(0xFFF9E3D5).withValues(alpha: 0.8)
                  : const Color(0xFFFDECE4).withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(30.sw),
              border: Border.all(
                color: selected ? selectRing : Colors.white.withValues(alpha: 0.5),
                width: 2.sw,
              ),
            ),
            padding: EdgeInsets.all(16.sw),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon box
                Container(
                  width: 46.sw,
                  height: 47.sh,
                  decoration: BoxDecoration(
                    color: orange,
                    borderRadius: BorderRadius.circular(10.sw),
                    boxShadow: [
                      BoxShadow(
                        color: orange.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: icon,
                ),

                SizedBox(height: 22.sh),

                Text(
                  title,
                  style: TextStyle(
                    color: brown,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    fontFamily: "Satoshi",
                  ),
                ),
                SizedBox(height: 6.sh),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: brown,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    fontFamily: "Satoshi",
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthBackgroundPattern extends StatelessWidget {
  const _AuthBackgroundPattern();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -100.sh,
            right: -100.sw,
            child: _AuthFloatingOrb(
              color: const Color(0xFFFFE0D3).withValues(alpha: 0.5),
              size: 400,
              duration: const Duration(seconds: 15),
            ),
          ),
          Positioned(
            bottom: 100.sh,
            left: -150.sw,
            child: _AuthFloatingOrb(
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

class _AuthFloatingOrb extends StatefulWidget {
  final Color color;
  final double size;
  final Duration duration;

  const _AuthFloatingOrb({required this.color, required this.size, required this.duration});

  @override
  State<_AuthFloatingOrb> createState() => _AuthFloatingOrbState();
}

class _AuthFloatingOrbState extends State<_AuthFloatingOrb> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..repeat();
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
