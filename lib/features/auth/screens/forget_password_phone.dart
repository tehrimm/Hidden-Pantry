import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:country_code_picker/country_code_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';
import 'package:flutter/material.dart';

import 'forget_password.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'forget_password_phone_otp.dart';
import 'package:hidden_pantry_app/core/utils/auth_validator.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';

import 'package:hidden_pantry_app/core/services/auth_service.dart';

class ForgetPasswordPhoneScreen extends StatefulWidget {
  final AuthService? authService;
  const ForgetPasswordPhoneScreen({super.key, this.authService});

  @override
  State<ForgetPasswordPhoneScreen> createState() =>
      _ForgetPasswordPhoneScreenState();
}

class _ForgetPasswordPhoneScreenState extends State<ForgetPasswordPhoneScreen> with TickerProviderStateMixin {
  late final AuthService _authService;

  // Colors
  static const Color bg = Color(0xFFFFF3EB);
  static const Color purple = Color(0xFF462F4D);
  static const Color hint = Color(0xFFBFA89A);
  static const Color orange = Color(0xFFF2894F);
  static const Color btnText = Color(0xFFFFF2EA);
  static const Color errText = Color(0xFFFD3250);

  final TextEditingController _phoneCtrl = TextEditingController();

  bool _loading = false;

  // Default Pakistan
  String _dialCode = "+92";

  // Field error
  String? _err;

  // Anti-spam cooldown
  DateTime? _nextAllowedAt;
  Timer? _cooldownTimer;
  int _cooldownLeft = 0;

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

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _phoneCtrl.dispose();
    _mainController.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    Toaster.show(context, msg);
  }

  bool _inCooldown() =>
      _nextAllowedAt != null && DateTime.now().isBefore(_nextAllowedAt!);

  void _startCooldown(int seconds) {
    _cooldownTimer?.cancel();
    _nextAllowedAt = DateTime.now().add(Duration(seconds: seconds));
    _cooldownLeft = seconds;

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final left = _nextAllowedAt!.difference(DateTime.now()).inSeconds;
      if (left <= 0) {
        t.cancel();
        if (!mounted) return;
        setState(() {
          _cooldownLeft = 0;
          _nextAllowedAt = null;
        });
      } else {
        if (!mounted) return;
        setState(() => _cooldownLeft = left);
      }
    });

    if (mounted) setState(() {});
  }

  String _buildE164() {
    var raw = _phoneCtrl.text.trim();
    raw = raw.replaceAll(RegExp(r'\s+'), '');
    raw = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (raw.startsWith('0')) {
      raw = raw.replaceFirst(RegExp(r'^0+'), '');
    }
    return '$_dialCode$raw';
  }

  bool _validate() {
    final raw = _phoneCtrl.text.trim();
    setState(() {
      _err = AuthValidator.validatePhone(raw);
    });
    return _err == null;
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'too-many-requests':
        return "Too many attempts. Wait, switch to mobile data, then try once. (too-many-requests)";
      case 'captcha-check-failed':
        return "Play Integrity / reCAPTCHA failed. Turn OFF VPN/WARP and try again. (captcha-check-failed)";
      case 'invalid-app-credential':
        return "App verification failed (Play Integrity). Update Play Services / try another network. (invalid-app-credential)";
      case 'app-not-authorized':
        return "App not authorized (SHA/package mismatch). Re-download google-services.json. (app-not-authorized)";
      case 'invalid-phone-number':
        return "Invalid number. Enter like 3001234567 (no starting 0) OR it will be auto-fixed. (invalid-phone-number)";
      default:
        return "${e.message ?? "Verification failed."} (${e.code})";
    }
  }

  Future<void> _verifyPhoneNumber() async {
    if (_loading) return;
    if (_inCooldown()) {
      _snack("Please wait $_cooldownLeft seconds before trying again.");
      return;
    }
    if (!_validate()) return;

    final phone = _buildE164();
    setState(() {
      _loading = true;
      _err = null;
    });
    _startCooldown(60);

    try {
      await _authService.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) {},
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          setState(() {
            _loading = false;
            _err = _friendlyAuthError(e);
          });
          _snack(_err!);
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          setState(() => _loading = false);
          _snack("OTP sent to $phone");
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ForgetPasswordPhoneOtpScreen(
                phone: phone,
                verificationId: verificationId,
              ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _err = "Error: $e";
      });
      _snack("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    final mq = MediaQuery.of(context);
    final horizontal = 30.sw;
    final topPad = mq.padding.top;

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
                    padding: EdgeInsets.fromLTRB(horizontal, topPad + 36.sh, horizontal, 20.sh),
                    child: Row(
                      children: [
                        BackButtonWidget(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const ForgetPasswordScreen()),
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
                      bottom: 14.sh + mq.padding.bottom,
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
                              "Reset\nPassword",
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
                        SizedBox(height: 18.sh),
                        _AnimatedWrapper(
                          animation: _staggeredAnimations[2],
                          child: SizedBox(
                            width: 260.sw,
                            child: Text(
                              "Please enter your phone number to reset the password",
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
                            height: 70.sh,
                            isError: _err != null,
                            child: Row(
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(left: 12.sw),
                                  child: CountryCodePicker(
                                    onChanged: (code) {
                                      setState(() {
                                        _dialCode = code.dialCode ?? _dialCode;
                                      });
                                    },
                                    initialSelection: 'PK',
                                    favorite: const ['+92', 'PK', '+1', 'US'],
                                    showCountryOnly: false,
                                    showOnlyCountryWhenClosed: false,
                                    alignLeft: false,
                                    padding: EdgeInsets.zero,
                                    textStyle: TextStyle(
                                      color: hint,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                      fontFamily: "Satoshi",
                                    ),
                                    barrierColor: Colors.black54,
                                    showDropDownButton: true,
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 36.sh,
                                  color: const Color(0xFFEAD2C6).withValues(alpha: 0.5),
                                ),
                                SizedBox(width: 12.sw),
                                Expanded(
                                  child: TextField(
                                    controller: _phoneCtrl,
                                    keyboardType: TextInputType.phone,
                                    cursorColor: purple,
                                    style: TextStyle(
                                      color: purple,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                      fontFamily: "Satoshi",
                                    ),
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      hintText: "Phone Number",
                                      hintStyle: TextStyle(
                                        color: hint,
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.2,
                                        fontFamily: "Satoshi",
                                      ),
                                      contentPadding: EdgeInsets.symmetric(vertical: 20.sh),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12.sw),
                              ],
                            ),
                          ),
                        ),
                        if (_err != null) ...[
                          SizedBox(height: 6.sh),
                          _ErrorText(text: _err!),
                        ],
                        if (_inCooldown()) ...[
                          SizedBox(height: 8.sh),
                          _AnimatedWrapper(
                            animation: _staggeredAnimations[4],
                            child: Text(
                              "Try again in $_cooldownLeft seconds",
                              style: TextStyle(
                                color: hint,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                                fontFamily: "Satoshi",
                              ),
                            ),
                          ),
                        ],
                        SizedBox(height: 40.sh),
                        _AnimatedWrapper(
                          animation: _staggeredAnimations[5],
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: (_loading || _inCooldown()) ? null : _verifyPhoneNumber,
                              child: Container(
                                width: 221.sw,
                                height: 62.sh,
                                decoration: BoxDecoration(
                                  color: (_loading || _inCooldown()) ? hint : orange,
                                  borderRadius: BorderRadius.circular(20.sw),
                                  boxShadow: [
                                    if (!_loading && !_inCooldown())
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
                                            child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
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
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            _inCooldown() ? "Wait..." : "Next",
                                            style: TextStyle(
                                              color: btnText, fontSize: 12.sp,
                                              fontWeight: FontWeight.bold, fontFamily: "Satoshi",
                                            ),
                                          ),
                                          SizedBox(width: 8.sw),
                                          Icon(
                                            Icons.arrow_forward_ios_rounded,
                                            size: 12.sw,
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
