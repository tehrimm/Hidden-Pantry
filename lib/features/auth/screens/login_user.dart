
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:hidden_pantry_app/features/onboarding/screens/loading_five.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:hidden_pantry_app/core/widgets/main_navigation_shell.dart';
import 'login_nutritionist.dart';
import 'signup_user.dart';
import 'forget_password.dart';
import 'nutritionist_signup_wrapper.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';
import 'package:hidden_pantry_app/core/utils/auth_validator.dart';
import 'package:hidden_pantry_app/core/services/auth_service.dart';
import 'package:hidden_pantry_app/features/user/services/user_service.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';

class UserLoginScreen extends StatefulWidget {
  final AuthService? authService;
  const UserLoginScreen({super.key, this.authService});

  @override
  State<UserLoginScreen> createState() => _UserLoginScreenState();
}

class _UserLoginScreenState extends State<UserLoginScreen> with TickerProviderStateMixin {
  late final AuthService _authService;

  // Controllers
  final _gmailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  // Faster to reuse
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  bool _obscurePassword = true;
  bool _loading = false;

  String? _gmailErr;
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
    _authService = widget.authService ?? AuthService();

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
    _gmailCtrl.dispose();
    _passwordCtrl.dispose();
    _mainController.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    Toaster.show(context, msg, isError: isError);
  }

  void _setLoading(bool v) {
    if (!mounted) return;
    setState(() => _loading = v);
  }

  bool _validate() {
    final email = _gmailCtrl.text.trim();
    final pass = _passwordCtrl.text;

    setState(() {
      _gmailErr = AuthValidator.validateEmail(email);
      if (_gmailErr == "*email field is required") {
        _gmailErr = "*field is required";
      }
      _passErr = AuthValidator.validatePassword(pass);
    });

    return _gmailErr == null && _passErr == null;
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

    final email = _gmailCtrl.text.trim();
    final pass = _passwordCtrl.text;

    _setLoading(true);
    try {
      final sw = Stopwatch()..start();

      final cred = await _authService.loginWithEmail(email, pass);
      final user = cred?.user;

      if (user != null) {
        final nutDoc = await FirebaseFirestore.instance
            .collection('nutritionists')
            .doc(user.uid)
            .get();

        if (kDebugMode) debugPrint("Login auth + role check took ${sw.elapsedMilliseconds}ms");

        if (!mounted) return;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (nutDoc.exists && nutDoc.data()?['verificationStatus'] != null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => NutritionistSignupWrapper()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => MainNavigationShell()),
            );
          }
        });
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.code == "user-not-found" || e.code == "wrong-password" || e.code == "invalid-credential") {
          _gmailErr = "*invalid email or password";
          _passErr = "*invalid email or password";
        } else if (e.code == "invalid-email") {
          _gmailErr = "*invalid email";
        } else {
          _snack("${e.message ?? "Login failed"}", isError: true);
        }
      });
    } catch (_) {
      _snack("Login failed", isError: true);
    } finally {
      if (mounted) _setLoading(false);
    }
  }

  Future<void> _onGoogleLogin() async {
    _setLoading(true);
    try {
      final googleUser = await _googleSignIn.signIn();
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
        UserService().ensureUserDoc(user).catchError((e) {
          if (kDebugMode) debugPrint("Background user sync failed: $e");
        });

        final nutDoc = await FirebaseFirestore.instance
            .collection('nutritionists')
            .doc(user.uid)
            .get();

        if (!mounted) return;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (nutDoc.exists && nutDoc.data()?['verificationStatus'] != null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => NutritionistSignupWrapper()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => MainNavigationShell()),
            );
          }
        });
      }
    } on FirebaseAuthException catch (e) {
      _snack("${e.message ?? "Google login failed"}", isError: true);
    } catch (_) {
      _snack("Google login failed", isError: true);
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
        UserService().ensureUserDoc(user).catchError((e) {
          if (kDebugMode) debugPrint("Background user sync failed: $e");
        });

        final nutDoc = await FirebaseFirestore.instance
            .collection('nutritionists')
            .doc(user.uid)
            .get();

        if (!mounted) return;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (nutDoc.exists && nutDoc.data()?['verificationStatus'] != null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => NutritionistSignupWrapper()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => MainNavigationShell()),
            );
          }
        });
      }
    } catch (_) {
      _snack("Apple login failed");
    } finally {
      if (mounted) _setLoading(false);
    }
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
                                        builder: (_) => const LoginNutritionistScreen(),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    "Nutritionist",
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
                              "Login to get Started",
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
                              errorText: _gmailErr,
                              child: TextField(
                                controller: _gmailCtrl,
                                cursorColor: purple,
                                textAlignVertical: TextAlignVertical.center,
                                style: TextStyle(
                                  color: (_gmailErr != null) ? errText : enabledText,
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
                                          color: Colors.white.withValues(alpha: 0.4),
                                          width: 1,
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
                                          color: Colors.white.withValues(alpha: 0.4),
                                          width: 1,
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
                                      builder: (_) => const SignupUserScreen(),
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



