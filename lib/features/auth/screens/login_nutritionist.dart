
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:hidden_pantry_app/features/onboarding/screens/loading_five.dart';
import 'nutritionist_signup_wrapper.dart';
import 'signup_nutritionist_step2.dart';
import 'signup_nutritionist.dart';
import 'forget_password.dart';
import 'login_user.dart';
import 'package:hidden_pantry_app/core/utils/auth_validator.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';

class LoginNutritionistScreen extends StatefulWidget {
  const LoginNutritionistScreen({super.key});

  @override
  State<LoginNutritionistScreen> createState() => _LoginNutritionistScreenState();
}

class _LoginNutritionistScreenState extends State<LoginNutritionistScreen> with TickerProviderStateMixin {
  // Controllers
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _loading = false;

  String? _emailErr;
  String? _passErr;

  // Colors
  static const Color bg = Color(0xFFFFF3EB);
  static const Color purple = Color(0xFF462F4D);

  static const Color hint = Color(0xFFBFA89A);
  static const Color enabledText = Color(0xFF462F4D);

  static const Color btnOrange = Color(0xFFF2894F);
  static const Color btnText = Color(0xFFFFF2EA);

  static const Color errText = Color(0xFFFD3250);

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
      8,
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
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _mainController.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    Toaster.show(context, msg);
  }

  void _setLoading(bool v) {
    if (!mounted) return;
    setState(() => _loading = v);
  }

  bool _validate() {
    _emailErr = null;
    _passErr = null;

    final email = _emailCtrl.text.trim();
    final pass = _passwordCtrl.text;

    bool ok = true;

    _emailErr = AuthValidator.validateEmail(email);
    if (_emailErr != null) {
      if (_emailErr == "*email field is required") {
        _emailErr = "*field is required";
      }
      ok = false;
    }

    if (pass.isEmpty) {
      _passErr = "*password field is required";
      ok = false;
    } else if (pass.length < 6) {
      _passErr = "*password is too weak";
      ok = false;
    }

    setState(() {});
    return ok;
  }

  void _goLoadingFive() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LoadingFive()),
    );
  }

  Future<void> _onLogin() async {
    if (!_validate()) return;

    final email = _emailCtrl.text.trim();
    final pass = _passwordCtrl.text;

    _setLoading(true);
    try {
      final userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );

      final user = userCred.user;
      if (user == null) throw Exception("Login failed");

      final doc = await FirebaseFirestore.instance
          .collection('nutritionists')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
             _snack("No nutritionist account found for this email.");
        }
        return;
      }

      if (!mounted) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => NutritionistSignupWrapper()),
        );
      });

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.code == "user-not-found" || e.code == "wrong-password" || e.code == "invalid-credential") {
          _emailErr = "*invalid email or password";
          _passErr = "*invalid email or password";
        } else if (e.code == "invalid-email") {
          _emailErr = "*invalid email";
        } else {
          _snack("${e.message ?? "Login failed (Error: ${e.code})"}");
        }
      });
    } catch (e) {
      _snack("Login failed: $e");
    } finally {
      if (mounted) _setLoading(false);
    }
  }

  Future<void> _onGoogleLogin() async {
    _setLoading(true);
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        _setLoading(false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final cred = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = cred.user;
      if (user != null) {
        await _handleSocialLoginResult(user);
      }
    } catch (e) {
      _snack("Google login failed: $e");
    } finally {
      if (mounted) _setLoading(false);
    }
  }

  Future<void> _onAppleLogin() async {
    _setLoading(true);
    try {
      final appleCred = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      );

      final oauthCred = OAuthProvider("apple.com").credential(
        idToken: appleCred.identityToken,
        accessToken: appleCred.authorizationCode,
      );

      final cred = await FirebaseAuth.instance.signInWithCredential(oauthCred);
      final user = cred.user;
      if (user != null) {
        await _handleSocialLoginResult(user);
      }
    } catch (e) {
      _snack("Apple login failed: $e");
    } finally {
      if (mounted) _setLoading(false);
    }
  }

  Future<void> _handleSocialLoginResult(User user) async {
    final doc = await FirebaseFirestore.instance
        .collection('nutritionists')
        .doc(user.uid)
        .get();

    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (doc.exists) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const NutritionistSignupWrapper()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SignupNutritionistStep2(
              fullName: user.displayName ?? "Nutritionist",
              email: user.email ?? "",
              phoneNumber: "",
              password: null,
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    final mq = MediaQuery.of(context);
    final horizontal = 30.sw;
    final topPad = mq.padding.top;

    final fieldHeight = 70.sh;
    final radius = 30.sw;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _goLoadingFive();
      },
      child: Scaffold(
        backgroundColor: bg,
        resizeToAvoidBottomInset: false,
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SafeArea(
            top: false,
            child: Container(
              color: bg,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
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
                        left: horizontal,
                        right: horizontal,
                        top: topPad + 36.sh,
                        bottom: 14.sh + mq.padding.bottom + mq.viewInsets.bottom,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            _AnimatedWrapper(
                              animation: _staggeredAnimations[0],
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  BackButtonWidget(onPressed: _goLoadingFive),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const UserLoginScreen(),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      "User",
                                      style: TextStyle(
                                        color: purple,
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: "Satoshi",
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: 45.sh),

                            _AnimatedWrapper(
                              animation: _staggeredAnimations[1],
                              child: Text(
                                "Login",
                                style: TextStyle(
                                  color: purple,
                                  fontSize: 40.sp,
                                  fontWeight: FontWeight.w900,
                                  height: 1.1,
                                  fontFamily: "Satoshi",
                                ),
                              ),
                            ),

                            SizedBox(height: 10.sh),

                            _AnimatedWrapper(
                              animation: _staggeredAnimations[2],
                              child: Text(
                                "Login to your professional account",
                                style: TextStyle(
                                  color: purple,
                                  fontSize: 15.sp,
                                  fontFamily: "Satoshi",
                                ),
                              ),
                            ),

                            SizedBox(height: 30.sh),

                            _AnimatedWrapper(
                              animation: _staggeredAnimations[3],
                              child: _LabeledField(
                                height: fieldHeight,
                                errorText: _emailErr,
                                child: TextField(
                                  controller: _emailCtrl,
                                  cursorColor: purple,
                                  textAlignVertical: TextAlignVertical.center,
                                  style: TextStyle(
                                    color: (_emailErr != null) ? errText : enabledText,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                    fontFamily: "Satoshi",
                                  ),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    hintText: "Email",
                                    hintStyle: TextStyle(
                                      color: hint,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.2,
                                      fontFamily: "Satoshi",
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 30.sw,
                                      vertical: 22.sh,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(height: 16.sh),

                            _AnimatedWrapper(
                              animation: _staggeredAnimations[4],
                              child: _LabeledField(
                                height: fieldHeight,
                                errorText: _passErr,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _passwordCtrl,
                                        obscureText: _obscurePassword,
                                        cursorColor: purple,
                                        textAlignVertical: TextAlignVertical.center,
                                        style: TextStyle(
                                          color: (_passErr != null) ? errText : enabledText,
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.2,
                                          fontFamily: "Satoshi",
                                        ),
                                        decoration: InputDecoration(
                                          border: InputBorder.none,
                                          hintText: "Password",
                                          hintStyle: TextStyle(
                                            color: hint,
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: 0.2,
                                            fontFamily: "Satoshi",
                                          ),
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 30.sw,
                                            vertical: 22.sh,
                                          ),
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => setState(
                                        () => _obscurePassword = !_obscurePassword,
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.only(right: 16.sw),
                                        child: Image.asset(
                                          _obscurePassword
                                              ? "assets/icons/eye_disable.png"
                                              : "assets/icons/eye.png",
                                          width: 19.sw,
                                          height: 20.sw,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            SizedBox(height: 10.sh),

                            _AnimatedWrapper(
                              animation: _staggeredAnimations[4],
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const ForgetPasswordScreen(),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    "Forget Password?",
                                    style: TextStyle(
                                      color: purple,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.3,
                                      fontFamily: "Satoshi",
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(height: 60.sh),

                            _AnimatedWrapper(
                              animation: _staggeredAnimations[5],
                              child: GestureDetector(
                                onTap: _loading ? null : _onLogin,
                                child: Container(
                                  width: double.infinity,
                                  height: 62.sh,
                                  decoration: BoxDecoration(
                                    color: btnOrange,
                                    borderRadius: BorderRadius.circular(20.sw),
                                    boxShadow: [
                                      BoxShadow(
                                        color: btnOrange.withValues(alpha: 0.3),
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
                                              width: 18.sw,
                                              height: 18.sw,
                                              child: const CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: btnText,
                                              ),
                                            ),
                                            SizedBox(width: 10.sw),
                                            Text(
                                              "Signing in...",
                                              style: TextStyle(
                                                color: btnText,
                                                fontSize: 12.sp,
                                                fontWeight: FontWeight.bold,
                                                fontFamily: "Satoshi",
                                              ),
                                            ),
                                          ],
                                        )
                                      : Text(
                                          "Login",
                                          style: TextStyle(
                                            color: btnText,
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: "Satoshi",
                                          ),
                                        ),
                                ),
                              ),
                            ),

                            SizedBox(height: 16.sh),

                            _AnimatedWrapper(
                              animation: _staggeredAnimations[6],
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: _loading ? null : _onGoogleLogin,
                                      child: Container(
                                        height: 59.sh,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF9E3D5),
                                          borderRadius: BorderRadius.circular(15.sw),
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 1.5,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Image.asset(
                                          "assets/logos/google.png",
                                          width: 48.sw,
                                          height: 27.sh,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12.sw),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: _loading ? null : _onAppleLogin,
                                      child: Container(
                                        height: 59.sh,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF9E3D5),
                                          borderRadius: BorderRadius.circular(15.sw),
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 1.5,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Image.asset(
                                          "assets/logos/apple.png",
                                          width: 70.sw,
                                          height: 44.sh,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: 32.sh),

                            _AnimatedWrapper(
                              animation: _staggeredAnimations[7],
                              child: Center(
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const SignupNutritionistScreen(),
                                      ),
                                    );
                                  },
                                  child: RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                        color: purple,
                                        fontSize: 14.sp,
                                        fontFamily: "Satoshi",
                                      ),
                                      children: const [
                                        TextSpan(text: "Don't have an account? "),
                                        TextSpan(
                                          text: "Register",
                                          style: TextStyle(fontWeight: FontWeight.w900),
                                        ),
                                      ],
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

class _LabeledField extends StatelessWidget {
  final double height;
  final String? errorText;
  final Widget child;

  const _LabeledField({
    required this.height,
    required this.child,
    required this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final isError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
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
        ),
        if (isError) ...[
          SizedBox(height: 6.sh),
          Padding(
            padding: EdgeInsets.only(left: 12.sw),
            child: Text(
              errorText!,
              style: TextStyle(
                color: const Color(0xFFFD3250),
                fontSize: 10.sp,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
                fontFamily: "Satoshi",
              ),
            ),
          ),
        ],
      ],
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



