import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:hidden_pantry_app/features/onboarding/screens/loading_five.dart';
import 'nutritionist_signup_wrapper.dart';
import 'signup_nutritionist_step2.dart';
import 'forget_password.dart';
import 'login_user.dart';

class LoginNutritionistScreen extends StatefulWidget {
  const LoginNutritionistScreen({super.key});

  @override
  State<LoginNutritionistScreen> createState() => _LoginNutritionistScreenState();
}

class _LoginNutritionistScreenState extends State<LoginNutritionistScreen> {
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

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _setLoading(bool v) {
    if (!mounted) return;
    setState(() => _loading = v);
  }

  bool _validate() {
    _emailErr = null;
    _passErr = null;

    final email = _emailCtrl.text.trim();
    final pass = _passwordCtrl.text.trim();

    bool ok = true;

    if (email.isEmpty ||
        email.length < 3 ||
        !RegExp(r"^[a-zA-Z0-9._]+$").hasMatch(email)) {
      _emailErr = "*incorrect email";
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
    final pass = _passwordCtrl.text.trim();

    _setLoading(true);
    try {
      // 1. Authenticate with Firebase Auth
      final userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );

      final user = userCred.user;
      if (user == null) throw Exception("Login failed");

      // 2. Check if user exists in 'nutritionists' collection
      final doc = await FirebaseFirestore.instance
          .collection('nutritionists')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        // Not a nutritionist (maybe a homecook trying to login here?)
        await FirebaseAuth.instance.signOut();
        if (mounted) {
             _snack("No nutritionist account found for this email.");
        }
        return;
      }

      // 3. Navigate to Wrapper which handles pending/approved logic
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => NutritionistSignupWrapper()),
      );

    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == "user-not-found") {
          _emailErr = "*user not found";
        } else if (e.code == "wrong-password") {
          _passErr = "*wrong password";
        } else if (e.code == "invalid-email") {
          _emailErr = "*invalid email";
        } else {
          _snack("${e.message ?? "Login failed"}");
        }
      });
    } catch (e) {
      _snack("Login failed: $e");
    } finally {
      _setLoading(false);
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
      await _handleSocialLoginResult(cred.user!);
    } catch (e) {
      _snack("Google login failed: $e");
    } finally {
      _setLoading(false);
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
      await _handleSocialLoginResult(cred.user!);
    } catch (e) {
      _snack("Apple login failed: $e");
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _handleSocialLoginResult(User user) async {
    // Check if user exists in 'nutritionists' collection
    final doc = await FirebaseFirestore.instance
        .collection('nutritionists')
        .doc(user.uid)
        .get();

    if (doc.exists) {
      // Existing nutritionist, go to wrapper
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const NutritionistSignupWrapper()),
      );
    } else {
      // NEW nutritionist - must upload certificate
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SignupNutritionistStep2(
            fullName: user.displayName ?? "Nutritionist",
            email: user.email ?? "",
            phoneNumber: "", // will be collected later if needed
            password: null, // social login
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = mq.size;

    // Simple responsive scaling
    double s(double v) {
      final base = math.min(size.width / 393.0, size.height / 852.0);
      return v * base;
    }

    final horizontal = s(30);
    final topPad = mq.padding.top;

    final fieldHeight = s(70);
    final radius = s(30);

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
                    // Background fill
                    const PatternBackground(),

                    // Main scroll content
                    SingleChildScrollView(
                      padding: EdgeInsets.only(
                        left: horizontal,
                        right: horizontal,
                        top: topPad + s(51),
                        bottom: s(14) + mq.padding.bottom + mq.viewInsets.bottom,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            // Top row (Back + User)
                            Row(
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
                                      fontSize: s(14),
                                      fontWeight: FontWeight.w700,
                                      fontFamily: "Satoshi",
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: s(45)),

                            Text(
                              "Nutritionist\nLogin",
                              style: TextStyle(
                                color: purple,
                                fontSize: s(40),
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                                fontFamily: "Satoshi",
                              ),
                            ),

                            SizedBox(height: s(32)),

                            // Google + Apple buttons
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: _loading ? null : _onGoogleLogin,
                                    child: Container(
                                      height: s(59),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF9E3D5),
                                        borderRadius: BorderRadius.circular(s(15)),
                                      ),
                                      alignment: Alignment.center,
                                      child: Image.asset(
                                        "assets/Logos/google.png",
                                        width: s(48),
                                        height: s(27),
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: s(12)),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: _loading ? null : _onAppleLogin,
                                    child: Container(
                                      height: s(59),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF9E3D5),
                                        borderRadius: BorderRadius.circular(s(15)),
                                      ),
                                      alignment: Alignment.center,
                                      child: Image.asset(
                                        "assets/Logos/apple.png",
                                        width: s(70),
                                        height: s(44),
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: s(24)),

                            Text(
                              "Or login to your professional account",
                              style: TextStyle(
                                color: purple,
                                fontSize: s(15),
                                fontFamily: "Satoshi",
                              ),
                            ),

                            SizedBox(height: s(30)),

                            // Email field
                            _LabeledField(
                              height: fieldHeight,
                              errorText: _emailErr,
                              child: TextField(
                                controller: _emailCtrl,
                                cursorColor: purple,
                                textAlignVertical: TextAlignVertical.center,
                                style: TextStyle(
                                  color: (_emailErr != null) ? errText : enabledText,
                                  fontSize: s(12),
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                  fontFamily: "Satoshi",
                                ),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: "Email",
                                  hintStyle: TextStyle(
                                    color: hint,
                                    fontSize: s(12),
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.2,
                                    fontFamily: "Satoshi",
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: s(30),
                                    vertical: s(22),
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(height: s(16)),

                            // Password field
                            _LabeledField(
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
                                        fontSize: s(12),
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.2,
                                        fontFamily: "Satoshi",
                                      ),
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        hintText: "Password",
                                        hintStyle: TextStyle(
                                          color: hint,
                                          fontSize: s(12),
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 0.2,
                                          fontFamily: "Satoshi",
                                        ),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: s(30),
                                          vertical: s(22),
                                        ),
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => setState(
                                      () => _obscurePassword = !_obscurePassword,
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.only(right: s(16)),
                                      child: Image.asset(
                                        _obscurePassword
                                            ? "assets/icons/eye-disable.png"
                                            : "assets/icons/eye.png",
                                        width: s(19),
                                        height: s(20),
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: s(10)),

                            Align(
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
                                    fontSize: s(14),
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.3,
                                    fontFamily: "Satoshi",
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(height: s(60)),

                            // Login button
                            GestureDetector(
                              onTap: _loading ? null : _onLogin,
                              child: Container(
                                width: double.infinity,
                                height: s(62),
                                decoration: BoxDecoration(
                                  color: btnOrange,
                                  borderRadius: BorderRadius.circular(s(20)),
                                ),
                                alignment: Alignment.center,
                                child: _loading
                                    ? Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: s(18),
                                            height: s(18),
                                            child: const CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                          SizedBox(width: s(10)),
                                          Text(
                                            "Signing in...",
                                            style: TextStyle(
                                              color: btnText,
                                              fontSize: s(12),
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
                                          fontSize: s(12),
                                          fontWeight: FontWeight.bold,
                                          fontFamily: "Satoshi",
                                        ),
                                      ),
                              ),
                            ),

                            SizedBox(height: s(40)),
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

class _LabeledField extends StatelessWidget {
  final double height;
  final String? errorText;
  final Widget child;

  const _LabeledField({
    required this.height,
    required this.child,
    required this.errorText,
  });

  static const Color fieldBg = Color(0xFFFDECE4);
  static const Color errFieldBg = Color(0xFFFFE0DD);

  @override
  Widget build(BuildContext context) {
    final isError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: height,
          decoration: BoxDecoration(
            color: isError ? errFieldBg : fieldBg,
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.hardEdge,
          child: child,
        ),
        if (isError) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: const TextStyle(
              color: Color(0xFFFD3250),
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
              fontFamily: "Satoshi",
            ),
          ),
        ],
      ],
    );
  }
}



