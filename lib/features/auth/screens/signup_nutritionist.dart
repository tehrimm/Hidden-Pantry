import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'signup_nutritionist_step2.dart';
import 'nutritionist_signup_wrapper.dart';
import 'package:hidden_pantry_app/features/onboarding/screens/loading_five.dart';
import 'package:hidden_pantry_app/features/onboarding/screens/terms_and_condition.dart';
import 'package:hidden_pantry_app/core/utils/auth_validator.dart';
import 'login_nutritionist.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';

class SignupNutritionistScreen extends StatefulWidget {
  const SignupNutritionistScreen({super.key});

  @override
  State<SignupNutritionistScreen> createState() => _SignupNutritionistScreenState();
}

class _SignupNutritionistScreenState extends State<SignupNutritionistScreen> {
  // Controllers
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  // UI
  bool _obscurePassword = true;
  bool _loading = false;

  // Errors
  String? _nameErr;
  String? _emailErr;
  String? _phoneErr;
  String? _passErr;

  // Country code
  String _countryCode = "+92";

  // Colors
  static const Color bg = Color(0xFFFFF3EB);
  static const Color purple = Color(0xFF462F4D);
  static const Color hint = Color(0xFFBFA89A);
  static const Color enabledText = Color(0xFF462F4D);
  static const Color stroke = Color(0xFFF5DDCE);
  static const Color btnOrange = Color(0xFFF2894F);
  static const Color btnText = Color(0xFFFFF2EA);
  static const Color errText = Color(0xFFFD3250);

  // Base size
  static const double _baseW = 393;
  static const double _baseH = 852;

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ---------------- VALIDATION ----------------
  bool _validate() {
    _nameErr = _emailErr = _phoneErr = _passErr = null;

    final name = _fullNameCtrl.text.trim();
    final emailUser = _emailCtrl.text.trim();
    final phoneDigits = _phoneCtrl.text.replaceAll(RegExp(r"\D"), "");
    final pass = _passwordCtrl.text;

    bool ok = true;

    if (name.isEmpty ||
        name.length < 3 ||
        !RegExp(r"^[a-zA-Z][a-zA-Z\s'.-]+$").hasMatch(name)) {
      _nameErr = "*invalid name";
      ok = false;
    }

    _emailErr = AuthValidator.validateEmail(emailUser);
    if (_emailErr != null) {
      if (_emailErr == "*email field is required") {
        _emailErr = "*field is required";
      }
      ok = false;
    }

    if (phoneDigits.length < 7) {
      _phoneErr = "*phone number not found";
      ok = false;
    }

    if (pass.length < 6) {
      _passErr = "*password is too weak";
      ok = false;
    }

    setState(() {});

    if (!ok) {
      if (_emailErr != null) {
        _snack("Email Error: $_emailErr");
      } else if (_nameErr != null) {
        _snack("Name Error: $_nameErr");
      } else if (_phoneErr != null) {
        _snack("Phone Error: $_phoneErr");
      } else if (_passErr != null) {
        _snack("Password Error: $_passErr");
      }
    }
    return ok;
  }

  // ---------------- HELPERS ----------------
  void _snack(String msg) {
    if (!mounted) return;
    Toaster.show(context, msg);
  }

  void _goLoadingFive() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LoadingFive()),
    );
  }

  void _onNext() {
    if (!_validate()) return;

    final email = _emailCtrl.text.trim();
    
    var rawPhone = _phoneCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (rawPhone.startsWith('0')) {
      rawPhone = rawPhone.replaceFirst(RegExp(r'^0+'), '');
    }
    final phone = "$_countryCode$rawPhone";

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SignupNutritionistStep2(
          fullName: _fullNameCtrl.text.trim(),
          email: email,
          phoneNumber: phone,
          password: _passwordCtrl.text.trim(),
        ),
      ),
    );
  }

  Future<void> _onGoogleLogin() async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final cred = await FirebaseAuth.instance.signInWithCredential(credential);
      await _handleSocialLoginResult(cred.user!);
    } catch (e) {
      _snack("Google signup failed: $e");
    }
  }

  Future<void> _onAppleLogin() async {
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
      _snack("Apple signup failed: $e");
    }
  }

  Future<void> _handleSocialLoginResult(User user) async {
    // Check if user exists in 'nutritionists' collection
    final doc = await FirebaseFirestore.instance
        .collection('nutritionists')
        .doc(user.uid)
        .get();

    if (doc.exists) {
      // Already a nutritionist, go to wrapper
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => NutritionistSignupWrapper()),
      );
    } else {
      // NEW nutritionist - go to Step 2
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SignupNutritionistStep2(
            fullName: user.displayName ?? "Nutritionist",
            email: user.email ?? "",
            phoneNumber: "", 
            password: null, // social login
          ),
        ),
      );
    }
  }

  // ======================= UI =======================
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final h = mq.size.height;

    final s = math.min(w / _baseW, h / _baseH);
    double sx(double v) => v * s;
    double sy(double v) => v * s;

    final fieldH = sy(70);
    final baseGap = sy(16);
    final errOffset = sy(4);

    EdgeInsets padMain() =>
        EdgeInsets.symmetric(horizontal: sx(30), vertical: sy(22));

    final topPad = mq.padding.top;

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _goLoadingFive();
      },
      child: Scaffold(
        backgroundColor: bg,
        resizeToAvoidBottomInset: false,
        body: Center(
          child: SizedBox(
            width: sx(_baseW),
            height: sy(_baseH),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(sx(30)),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  const PatternBackground(),

                  Column(
                    children: [
                      // Fixed Top row (Back + Login)
                      Padding(
                        padding: EdgeInsets.fromLTRB(sx(30), topPad + sy(20), sx(30), sy(20)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            BackButtonWidget(onPressed: _goLoadingFive),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const LoginNutritionistScreen()),
                                );
                              },
                              child: Text(
                                "Login",
                                style: TextStyle(
                                  color: purple,
                                  fontSize: sx(14),
                                  fontWeight: FontWeight.w700,
                                  fontFamily: "Satoshi",
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Main scroll content
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.only(
                            left: sx(30),
                            right: sx(30),
                            bottom: sy(30) + mq.padding.bottom + mq.viewInsets.bottom,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                          // Title
                          SizedBox(
                            width: sx(337),
                            child: Text(
                              "Register",
                              style: TextStyle(
                                color: purple,
                                fontSize: sx(40),
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                                fontFamily: "Satoshi",
                              ),
                            ),
                          ),

                          SizedBox(height: sy(46)),

                          // ================= FULL NAME =================
                          SizedBox(
                            width: sx(332),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldBox(
                                  width: sx(332),
                                  height: fieldH,
                                  isError: _nameErr != null,
                                  child: TextField(
                                    controller: _fullNameCtrl,
                                    onChanged: (_) => setState(() {}),
                                    cursorColor: purple,
                                    textAlignVertical: TextAlignVertical.center,
                                    style: TextStyle(
                                      color: (_nameErr != null)
                                          ? errText
                                          : (_fullNameCtrl.text.trim().isEmpty
                                              ? hint
                                              : enabledText),
                                      fontSize: sx(12),
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                      fontFamily: "Satoshi",
                                    ),
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      hintText: "Full Name",
                                      hintStyle: TextStyle(
                                        color: hint,
                                        fontSize: sx(12),
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.2,
                                        fontFamily: "Satoshi",
                                      ),
                                      isDense: false,
                                      contentPadding: padMain(),
                                    ),
                                  ),
                                ),
                                if (_nameErr != null) ...[
                                  SizedBox(height: errOffset),
                                  Padding(
                                    padding: EdgeInsets.only(left: sx(12)),
                                    child: Text(
                                      _nameErr!,
                                      style: TextStyle(
                                        color: errText,
                                        fontSize: sx(10),
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.2,
                                        fontFamily: "Satoshi",
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          SizedBox(height: baseGap),

                          // ================= EMAIL ROW =================
                          SizedBox(
                            width: sx(332),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldBox(
                                  width: sx(332),
                                  height: fieldH,
                                  isError: _emailErr != null,
                                  child: TextField(
                                    controller: _emailCtrl,
                                    onChanged: (_) => setState(() {}),
                                    cursorColor: purple,
                                    textAlignVertical: TextAlignVertical.center,
                                    style: TextStyle(
                                      color: (_emailErr != null)
                                          ? errText
                                          : (_emailCtrl.text.trim().isEmpty
                                              ? hint
                                              : enabledText),
                                      fontSize: sx(12),
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                      fontFamily: "Satoshi",
                                    ),
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      hintText: "Email",
                                      hintStyle: TextStyle(
                                        color: hint,
                                        fontSize: sx(12),
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.2,
                                        fontFamily: "Satoshi",
                                      ),
                                      isDense: false,
                                      contentPadding: padMain(),
                                    ),
                                  ),
                                ),
                                if (_emailErr != null) ...[
                                  SizedBox(height: errOffset),
                                  Padding(
                                    padding: EdgeInsets.only(left: sx(11)),
                                    child: Text(
                                      _emailErr!,
                                      style: TextStyle(
                                        color: errText,
                                        fontSize: sx(10),
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.2,
                                        fontFamily: "Satoshi",
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          SizedBox(height: baseGap),

                          // ================= PHONE =================
                          SizedBox(
                            width: sx(332),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldBox(
                                  width: sx(332),
                                  height: fieldH,
                                  isError: _phoneErr != null,
                                  child: Row(
                                    children: [
                                      SizedBox(width: sx(10)),
                                      SizedBox(
                                        width: sx(135),
                                        child: CountryCodePicker(
                                          onChanged: (c) => setState(
                                            () => _countryCode = c.dialCode ?? "+92",
                                          ),
                                          initialSelection: _countryCode,
                                          favorite: const [
                                            "+92",
                                            "+91",
                                            "+971",
                                            "+44",
                                            "+1"
                                          ],
                                          alignLeft: true,
                                          padding: EdgeInsets.zero,
                                          showDropDownButton: false,
                                          textStyle: TextStyle(
                                            color: _phoneErr != null
                                                ? errText
                                                : purple,
                                            fontSize: sx(12),
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.2,
                                            fontFamily: "Satoshi",
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: sx(1),
                                        height: sy(36),
                                        color: stroke,
                                      ),
                                      SizedBox(width: sx(14)),
                                      Expanded(
                                        child: TextField(
                                          controller: _phoneCtrl,
                                          onChanged: (_) => setState(() {}),
                                          keyboardType: TextInputType.phone,
                                          cursorColor: purple,
                                          textAlignVertical:
                                              TextAlignVertical.center,
                                          style: TextStyle(
                                            color: (_phoneErr != null)
                                                ? errText
                                                : (_phoneCtrl.text.trim().isEmpty
                                                    ? hint
                                                    : enabledText),
                                            fontSize: sx(12),
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.2,
                                            fontFamily: "Satoshi",
                                          ),
                                          decoration: InputDecoration(
                                            border: InputBorder.none,
                                            hintText: "Phone Number",
                                            hintStyle: TextStyle(
                                              color: hint,
                                              fontSize: sx(12),
                                              fontWeight: FontWeight.w500,
                                              letterSpacing: 0.2,
                                              fontFamily: "Satoshi",
                                            ),
                                            isDense: false,
                                            contentPadding: EdgeInsets.only(
                                              top: sy(24),
                                              bottom: sy(18),
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: sx(12)),
                                    ],
                                  ),
                                ),
                                if (_phoneErr != null) ...[
                                  SizedBox(height: errOffset),
                                  Padding(
                                    padding: EdgeInsets.only(left: sx(12)),
                                    child: Text(
                                      _phoneErr!,
                                      style: TextStyle(
                                        color: errText,
                                        fontSize: sx(10),
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.2,
                                        fontFamily: "Satoshi",
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          SizedBox(height: baseGap),

                          // ================= PASSWORD =================
                          SizedBox(
                            width: sx(332),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldBox(
                                  width: sx(332),
                                  height: fieldH,
                                  isError: _passErr != null,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _passwordCtrl,
                                          onChanged: (_) => setState(() {}),
                                          obscureText: _obscurePassword,
                                          cursorColor: purple,
                                          textAlignVertical:
                                              TextAlignVertical.center,
                                          style: TextStyle(
                                            color: (_passErr != null)
                                                ? errText
                                                : (_passwordCtrl.text.isEmpty
                                                    ? hint
                                                    : enabledText),
                                            fontSize: sx(12),
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.2,
                                            fontFamily: "Satoshi",
                                          ),
                                          decoration: InputDecoration(
                                            border: InputBorder.none,
                                            hintText: "Password",
                                            hintStyle: TextStyle(
                                              color: hint,
                                              fontSize: sx(12),
                                              fontWeight: FontWeight.w500,
                                              letterSpacing: 0.2,
                                              fontFamily: "Satoshi",
                                            ),
                                            isDense: false,
                                            contentPadding: padMain(),
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => setState(
                                          () => _obscurePassword = !_obscurePassword,
                                        ),
                                        child: Padding(
                                          padding: EdgeInsets.only(right: sx(16)),
                                          child: Image.asset(
                                            _obscurePassword
                                                ? "assets/icons/eye-disable.png"
                                                : "assets/icons/eye.png",
                                            width: sx(19),
                                            height: sx(20),
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_passErr != null) ...[
                                  SizedBox(height: errOffset),
                                  Padding(
                                    padding: EdgeInsets.only(left: sx(12)),
                                    child: Text(
                                      _passErr!,
                                      style: TextStyle(
                                        color: errText,
                                        fontSize: sx(10),
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.2,
                                        fontFamily: "Satoshi",
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          SizedBox(height: sy(30)),

                          // Terms text
                          Center(
                            child: Column(
                              children: [
                                Text(
                                  "By registering you agree to our",
                                  style: TextStyle(
                                    color: purple,
                                    fontSize: sx(12),
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.2,
                                    fontFamily: "Satoshi",
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            TermsAndConditionScreen(viewOnly: true),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    "Terms and Conditions",
                                    style: TextStyle(
                                      color: purple,
                                      fontSize: sx(12),
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.2,
                                      fontFamily: "Satoshi",
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: sy(20)),

                          // Next button
                          GestureDetector(
                            onTap: _onNext,
                            child: Container(
                              width: sx(332),
                              height: sy(62),
                              decoration: BoxDecoration(
                                color: btnOrange,
                                borderRadius: BorderRadius.circular(sx(20)),
                              ),
                              alignment: Alignment.center,
                              child: _loading
                                  ? SizedBox(
                                      width: sx(18),
                                      height: sx(18),
                                      child: const CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      "Next",
                                      style: TextStyle(
                                        color: btnText,
                                        fontSize: sx(14),
                                        fontWeight: FontWeight.w700,
                                        fontFamily: "Satoshi",
                                      ),
                                    ),
                            ),
                          ),

                          SizedBox(height: sy(16)),

                          // Google + Apple row
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: _onGoogleLogin,
                                  child: Container(
                                    height: sy(59),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF9E3D5),
                                      borderRadius: BorderRadius.circular(sx(15)),
                                    ),
                                    alignment: Alignment.center,
                                    child: Image.asset(
                                      "assets/Logos/google.png",
                                      width: sx(48),
                                      height: sy(27),
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: sx(12)),
                              Expanded(
                                child: GestureDetector(
                                  onTap: _onAppleLogin,
                                  child: Container(
                                    height: sy(59),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF9E3D5),
                                      borderRadius: BorderRadius.circular(sx(15)),
                                    ),
                                    alignment: Alignment.center,
                                    child: Image.asset(
                                      "assets/Logos/apple.png",
                                      width: sx(70),
                                      height: sy(44),
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: sy(32)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldBox extends StatelessWidget {
  final double width;
  final double height;
  final bool isError;
  final Widget child;

  const _FieldBox({
    required this.width,
    required this.height,
    required this.isError,
    required this.child,
  });

  static const Color fieldBg = Color(0xFFFDECE4);
  static const Color errFieldBg = Color(0xFFFFE0DD);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: isError ? errFieldBg : fieldBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}



