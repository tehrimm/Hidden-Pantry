
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';
import 'login_user.dart';
import 'forget_password.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:hidden_pantry_app/core/utils/auth_validator.dart';

import 'package:hidden_pantry_app/core/services/auth_service.dart';

class ForgetPasswordEmailScreen extends StatefulWidget {
  final AuthService? authService;
  const ForgetPasswordEmailScreen({super.key, this.authService});

  @override
  State<ForgetPasswordEmailScreen> createState() =>
      _ForgetPasswordEmailScreenState();
}

class _ForgetPasswordEmailScreenState extends State<ForgetPasswordEmailScreen> with TickerProviderStateMixin {
  late final AuthService _authService;
  final _emailCtrl = TextEditingController();

  bool _loading = false;
  String? _emailErr;

  static const Color bg = Color(0xFFFFF3EB);
  static const Color purple = Color(0xFF462F4D);
  static const Color orange = Color(0xFFF2894F);
  static const Color btnText = Color(0xFFFFF2EA);
  static const Color hint = Color(0xFFBFA89A);
  static const Color errText = Color(0xFFFD3250);

  // Animations
  late AnimationController _mainController;
  late List<Animation<double>> _staggeredAnimations;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
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

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool _validate() {
    final email = _emailCtrl.text.trim();
    setState(() {
      _emailErr = AuthValidator.validateEmail(email);
    });
    return _emailErr == null;
  }

  Future<void> _sendEmailReset() async {
    if (!_validate()) return;

    setState(() => _loading = true);
    try {
      final email = _emailCtrl.text.trim();
      await _authService.sendPasswordResetEmail(email: email);
      _snack("Reset link sent to $email");
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const UserLoginScreen()),
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == "invalid-email") {
        setState(() => _emailErr = "*incorrect email");
      } else if (e.code == "user-not-found") {
        _snack("No account found for this email.");
      } else if (e.code == "too-many-requests") {
        _snack("Too many attempts. Try again later.");
      } else {
        _snack(e.message ?? "Failed to send reset email.");
      }
    } catch (_) {
      _snack("Something went wrong. Try again.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _mainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    final mq = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: bg,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        top: false,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30.sw),
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
              const _AuthBackgroundPattern(),

              const PatternBackground(),

              SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 30.sw,
                  right: 30.sw,
                  top: mq.padding.top + 36.sh,
                  bottom: 22.sh + mq.viewInsets.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AnimatedWrapper(
                      animation: _staggeredAnimations[0],
                      child: BackButtonWidget(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const ForgetPasswordScreen()),
                          );
                        },
                      ),
                    ),

                    SizedBox(height: 38.sh),

                    _AnimatedWrapper(
                      animation: _staggeredAnimations[1],
                      child: Text(
                        "Verify Email",
                        style: TextStyle(
                          color: purple,
                          fontSize: 40.sp,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                          fontFamily: "Satoshi",
                        ),
                      ),
                    ),

                    SizedBox(height: 12.sh),

                    _AnimatedWrapper(
                      animation: _staggeredAnimations[2],
                      child: SizedBox(
                        width: 290.sw,
                        child: Text(
                          "Enter your email and we will send you a password reset link.",
                          style: TextStyle(
                            color: purple,
                            fontSize: 15.sp,
                            fontFamily: "Satoshi",
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 26.sh),

                    _AnimatedWrapper(
                      animation: _staggeredAnimations[3],
                      child: _GlassField(
                        height: 62.sh,
                        isError: _emailErr != null,
                        child: Row(
                          children: [
                            SizedBox(width: 16.sw),
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
                              child: Image.asset(
                                "assets/icons/gmail.png",
                                width: 18.sw,
                                height: 18.sw,
                                fit: BoxFit.contain,
                              ),
                            ),
                            SizedBox(width: 12.sw),
                            Expanded(
                              child: TextField(
                                controller: _emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _sendEmailReset(),
                                cursorColor: purple,
                                style: TextStyle(
                                  color: (_emailErr != null) ? errText : purple,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: "Satoshi",
                                ),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: "Gmail",
                                  hintStyle: TextStyle(
                                    color: hint,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: "Satoshi",
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 12.sw),
                          ],
                        ),
                      ),
                    ),

                    if (_emailErr != null) ...[
                      SizedBox(height: 6.sh),
                      _ErrorText(text: _emailErr!),
                    ],

                    SizedBox(height: 28.sh),

                    _AnimatedWrapper(
                      animation: _staggeredAnimations[4],
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: _loading ? null : _sendEmailReset,
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
                            alignment: Alignment.center,
                            child: _loading
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 18.sw, height: 18.sw,
                                        child: const CircularProgressIndicator(strokeWidth: 2, color: btnText),
                                      ),
                                      SizedBox(width: 10.sw),
                                      Text(
                                        "Sending...",
                                        style: TextStyle(
                                          color: btnText, fontSize: 12.sp,
                                          fontWeight: FontWeight.bold, fontFamily: "Satoshi",
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    "Send Link",
                                    style: TextStyle(
                                      color: btnText, fontSize: 12.sp,
                                      fontWeight: FontWeight.bold, fontFamily: "Satoshi",
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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

class _GlassField extends StatelessWidget {
  final double height;
  final bool isError;
  final Widget child;
  const _GlassField({required this.height, required this.isError, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20.sw),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: isError 
                ? const Color(0xFFFFE0DD).withValues(alpha: 0.8)
                : const Color(0xFFFDECE4).withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20.sw),
            border: Border.all(
              color: isError 
                  ? const Color(0xFFFD3250).withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  final String text;
  const _ErrorText({required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 12.sw),
      child: Text(
        text,
        style: TextStyle(
          color: const Color(0xFFFD3250), fontSize: 10.sp,
          fontWeight: FontWeight.w500, letterSpacing: 0.2, fontFamily: "Satoshi",
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



