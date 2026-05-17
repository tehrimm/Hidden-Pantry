import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_user.dart';
import 'package:hidden_pantry_app/core/widgets/main_navigation_shell.dart';
import 'forget_password_phone.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';

class ForgetPasswordPhoneOtpScreen extends StatefulWidget {
  final String phone;
  final String verificationId;
  const ForgetPasswordPhoneOtpScreen({
    super.key,
    required this.phone,
    required this.verificationId,
  });

  @override
  State<ForgetPasswordPhoneOtpScreen> createState() =>
      _ForgetPasswordPhoneOtpScreenState();
}

class _ForgetPasswordPhoneOtpScreenState
    extends State<ForgetPasswordPhoneOtpScreen> with TickerProviderStateMixin {
  // Colors
  static const Color bg = Color(0xFFFFF3EB);
  static const Color purple = Color(0xFF462F4D);
  static const Color brown = Color(0xFF74503C);
  static const Color orange = Color(0xFFF2894F);
  static const Color btnText = Color(0xFFFFF2EA);
  static const Color resendRed = Color(0xFFFD3250);

  final List<TextEditingController> _ctrl =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focus = List.generate(6, (_) => FocusNode());

  bool _loading = false;

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
      7,
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
    for (final c in _ctrl) c.dispose();
    for (final f in _focus) f.dispose();
    _mainController.dispose();
    super.dispose();
  }

  String get _otp => _ctrl.map((e) => e.text.trim()).join();
  bool get _otpComplete => _otp.length == 6 && !_otp.contains(RegExp(r'\D'));

  void _setLoading(bool v) {
    if (!mounted) return;
    setState(() => _loading = v);
  }

  void _snack(String msg) {
    if (!mounted) return;
    Toaster.show(context, msg);
  }

  void _onChanged(int i, String v) {
    final value = v.trim();
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '').split('');
      if (digits.isEmpty) return;
      int idx = i;
      for (final d in digits) {
        if (idx >= 6) break;
        _ctrl[idx].text = d;
        idx++;
      }
      if (idx < 6) {
        _focus[idx].requestFocus();
      } else {
        FocusScope.of(context).unfocus();
      }
      setState(() {});
      return;
    }
    if (value.isNotEmpty) {
      if (i < 5) _focus[i + 1].requestFocus();
      setState(() {});
    }
  }

  void _onBackspace(int i) {
    if (_ctrl[i].text.isNotEmpty) {
      _ctrl[i].clear();
      setState(() {});
      return;
    }
    if (i > 0) {
      _focus[i - 1].requestFocus();
      _ctrl[i - 1].clear();
      setState(() {});
    }
  }

  Future<void> _verify() async {
    if (!_otpComplete) {
      _snack("Enter complete OTP");
      return;
    }

    _setLoading(true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: _otp,
      );

      final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCred.user;

      if (user != null) {
        try {
          var query = await FirebaseFirestore.instance
              .collection("users")
              .where("phone", isEqualTo: widget.phone)
              .get();

          if (query.docs.isEmpty) {
            String altPhone;
            if (widget.phone.contains(RegExp(r'\+\d+0'))) {
              altPhone = widget.phone.replaceFirst("0", "", widget.phone.indexOf(RegExp(r'\d')) + 1);
            } else {
              final match = RegExp(r'\+\d+').firstMatch(widget.phone);
              if (match != null) {
                altPhone = widget.phone.replaceFirst(match.group(0)!, "${match.group(0)}0");
              } else {
                altPhone = widget.phone;
              }
            }
            if (altPhone != widget.phone) {
              query = await FirebaseFirestore.instance
                  .collection("users")
                  .where("phone", isEqualTo: altPhone)
                  .get();
            }
          }

          if (query.docs.isEmpty) {
            await FirebaseAuth.instance.signOut();
            _snack("Account does not exist. Please sign up first.");
            return;
          }

          final existingDoc = query.docs.first;
          final String dbUid = existingDoc.id;
          final String authUid = user.uid;

          if (dbUid != authUid) {
            final String? email = existingDoc.data()['email'];
            if (email != null && email.isNotEmpty) {
              _snack("Identity Verified! Sending password reset link to $email...");
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                if (mounted) {
                   Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const UserLoginScreen()),
                    (route) => false,
                  );
                  _snack("Reset link sent! Please reset your password and login.");
                }
              } catch (e) {
                _snack("Verified, but could not send reset link. Try Email Reset instead.");
              }
            } else {
              _snack("Verified, but no email found for this account. Contact support.");
            }
            await FirebaseAuth.instance.signOut();
            return;
          }

          _snack("Login Successful!");
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const MainNavigationShell()),
              (route) => false,
            );
          }
        } catch (e) {
          await FirebaseAuth.instance.signOut();
          _snack("Login failed: $e");
        }
      }
    } on FirebaseAuthException catch (e) {
      _snack(e.message ?? "Verification failed");
    } catch (e) {
      _snack("Something went wrong: $e");
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _resend() async {
    if (_loading) return;
    _snack("Resend OTP tapped");
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    final mq = MediaQuery.of(context);
    final bool isTablet = mq.size.width >= 600;
    final horizontal = 30.sw;
    final topPad = mq.padding.top;

    final boxW = isTablet ? 55.0 : 48.sw;
    final boxH = isTablet ? 65.0 : 58.sh;

    return Scaffold(
      backgroundColor: bg,
      resizeToAvoidBottomInset: false,
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
                    padding: EdgeInsets.fromLTRB(horizontal, topPad + (isTablet ? 24.sh : 35.sh), horizontal, 20.sh),
                    child: Row(
                      children: [
                        BackButtonWidget(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const ForgetPasswordPhoneScreen()),
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
                      left: horizontal,
                      right: horizontal,
                      bottom: 22.sh + mq.viewInsets.bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 18.sh),
                        _AnimatedWrapper(
                          animation: _staggeredAnimations[1],
                          child: SizedBox(
                            width: 235.sw,
                            child: Text(
                              "Enter OTP",
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
                            width: 300.sw,
                            child: Text(
                              "Please enter the OTP sent to ${widget.phone}",
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
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(6, (i) {
                              return Padding(
                                padding: EdgeInsets.only(left: i == 0 ? 0 : 8.sw),
                                child: _OtpBox(
                                  width: boxW,
                                  height: boxH,
                                  brown: brown,
                                  purple: purple,
                                  controller: _ctrl[i],
                                  focusNode: _focus[i],
                                  onChanged: (v) => _onChanged(i, v),
                                  onBackspace: () => _onBackspace(i),
                                ),
                              );
                            }),
                          ),
                        ),
                        SizedBox(height: 26.sh),
                        _AnimatedWrapper(
                          animation: _staggeredAnimations[4],
                          child: GestureDetector(
                            onTap: _loading ? null : _verify,
                            child: Container(
                              width: double.infinity,
                              height: 62.sh,
                              decoration: BoxDecoration(
                                color: orange,
                                borderRadius: BorderRadius.circular(20.sw),
                                boxShadow: [
                                  if (!_loading)
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
                                          child: const CircularProgressIndicator(color: btnText, strokeWidth: 2),
                                        ),
                                        SizedBox(width: 10.sw),
                                        Text(
                                          "Verifying...",
                                          style: TextStyle(
                                            color: btnText, fontSize: 12.sp,
                                            fontWeight: FontWeight.bold, fontFamily: "Satoshi",
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      "Verify Code",
                                      style: TextStyle(
                                        color: btnText, fontSize: 12.sp,
                                        fontWeight: FontWeight.bold, fontFamily: "Satoshi",
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        SizedBox(height: 18.sh),
                        _AnimatedWrapper(
                          animation: _staggeredAnimations[5],
                          child: Center(
                            child: GestureDetector(
                              onTap: _resend,
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    color: purple,
                                    fontSize: 15.sp,
                                    fontFamily: "Satoshi",
                                  ),
                                  children: const [
                                    TextSpan(text: "Haven’t got the OTP yet? "),
                                    TextSpan(
                                      text: "Resend OTP",
                                      style: TextStyle(color: resendRed, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 40.sh),
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

class _OtpBox extends StatelessWidget {
  final double width;
  final double height;
  final Color brown;
  final Color purple;
  final TextEditingController controller;
  final FocusNode focusNode;

  final ValueChanged<String> onChanged;
  final VoidCallback onBackspace;

  const _OtpBox({
    required this.width,
    required this.height,
    required this.brown,
    required this.purple,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFFDECE4).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12.sw),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.sw),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Center(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 2,
              style: TextStyle(
                color: purple,
                fontSize: 22.sp,
                fontWeight: FontWeight.bold,
                fontFamily: "Satoshi",
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: const InputDecoration(
                counterText: "",
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onTap: () {
                if (controller.text.isNotEmpty) {
                  controller.selection = TextSelection.fromPosition(
                    TextPosition(offset: controller.text.length),
                  );
                }
              },
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
