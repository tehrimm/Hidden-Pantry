
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';
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

class _SignupNutritionistScreenState extends State<SignupNutritionistScreen> with TickerProviderStateMixin {
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

  // Animations
  late AnimationController _mainController;
  late List<Animation<double>> _staggeredAnimations;

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _staggeredAnimations = List.generate(
      10,
      (index) => CurvedAnimation(
        parent: _mainController,
        curve: Interval(
          0.1 + (index * 0.08),
          0.6 + (index * 0.04),
          curve: Curves.easeOutQuart,
        ),
      ),
    );

    _mainController.forward();
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _mainController.dispose();
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
    final doc = await FirebaseFirestore.instance
        .collection('nutritionists')
        .doc(user.uid)
        .get();

    if (doc.exists) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => NutritionistSignupWrapper()),
      );
    } else {
      if (!mounted) return;
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
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    final mq = MediaQuery.of(context);

    final fieldH = 70.sh;
    final baseGap = 16.sh;
    final errOffset = 4.sh;

    EdgeInsets padMain() =>
        EdgeInsets.symmetric(horizontal: 30.sw, vertical: 22.sh);

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
            width: 393.sw,
            height: 852.sh,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30.sw),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  const PatternBackground(),

                  Column(
                    children: [
                      _AnimatedWrapper(
                        animation: _staggeredAnimations[0],
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(30.sw, topPad + 36.sh, 30.sw, 20.sh),
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
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: "Satoshi",
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.only(
                            left: 30.sw,
                            right: 30.sw,
                            bottom: 30.sh + mq.padding.bottom + mq.viewInsets.bottom,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                          _AnimatedWrapper(
                            animation: _staggeredAnimations[1],
                            child: SizedBox(
                              width: 337.sw,
                              child: Text(
                                "Register",
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

                          SizedBox(height: 46.sh),

                          _AnimatedWrapper(
                            animation: _staggeredAnimations[2],
                            child: _GlassField(
                              height: fieldH,
                              isError: _nameErr != null,
                              child: TextField(
                                controller: _fullNameCtrl,
                                onChanged: (_) => setState(() {}),
                                cursorColor: purple,
                                textAlignVertical: TextAlignVertical.center,
                                style: TextStyle(
                                  color: (_nameErr != null) ? errText : enabledText,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                  fontFamily: "Satoshi",
                                ),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: "Full Name",
                                  hintStyle: TextStyle(
                                    color: hint,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.2,
                                    fontFamily: "Satoshi",
                                  ),
                                  contentPadding: padMain(),
                                ),
                              ),
                            ),
                          ),
                          if (_nameErr != null) ...[
                            SizedBox(height: errOffset),
                            _ErrorText(text: _nameErr!),
                          ],

                          SizedBox(height: baseGap),

                          _AnimatedWrapper(
                            animation: _staggeredAnimations[3],
                            child: _GlassField(
                              height: fieldH,
                              isError: _emailErr != null,
                              child: TextField(
                                controller: _emailCtrl,
                                onChanged: (_) => setState(() {}),
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
                                  contentPadding: padMain(),
                                ),
                              ),
                            ),
                          ),
                          if (_emailErr != null) ...[
                            SizedBox(height: errOffset),
                            _ErrorText(text: _emailErr!),
                          ],

                          SizedBox(height: baseGap),

                          _AnimatedWrapper(
                            animation: _staggeredAnimations[4],
                            child: _GlassField(
                              height: fieldH,
                              isError: _phoneErr != null,
                              child: Row(
                                children: [
                                  SizedBox(width: 10.sw),
                                  SizedBox(
                                    width: 135.sw,
                                    child: CountryCodePicker(
                                      onChanged: (c) => setState(
                                        () => _countryCode = c.dialCode ?? "+92",
                                      ),
                                      initialSelection: _countryCode,
                                      favorite: const ["+92", "+91", "+971", "+44", "+1"],
                                      alignLeft: true,
                                      padding: EdgeInsets.zero,
                                      showDropDownButton: false,
                                      textStyle: TextStyle(
                                        color: _phoneErr != null ? errText : purple,
                                        fontSize: 12.sw,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.2,
                                        fontFamily: "Satoshi",
                                      ),
                                    ),
                                  ),
                                  Container(width: 1.sw, height: 36.sh, color: stroke),
                                  SizedBox(width: 14.sw),
                                  Expanded(
                                    child: TextField(
                                      controller: _phoneCtrl,
                                      onChanged: (_) => setState(() {}),
                                      keyboardType: TextInputType.phone,
                                      cursorColor: purple,
                                      textAlignVertical: TextAlignVertical.center,
                                      style: TextStyle(
                                        color: (_phoneErr != null) ? errText : enabledText,
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
                                        contentPadding: EdgeInsets.only(top: 24.sh, bottom: 18.sh),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12.sw),
                                ],
                              ),
                            ),
                          ),
                          if (_phoneErr != null) ...[
                            SizedBox(height: errOffset),
                            _ErrorText(text: _phoneErr!),
                          ],

                          SizedBox(height: baseGap),

                          _AnimatedWrapper(
                            animation: _staggeredAnimations[5],
                            child: _GlassField(
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
                                        contentPadding: padMain(),
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                                    child: Padding(
                                      padding: EdgeInsets.only(right: 16.sw),
                                      child: Image.asset(
                                        _obscurePassword ? "assets/icons/eye_disable.png" : "assets/icons/eye.png",
                                        width: 19.sw, height: 20.sw, fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_passErr != null) ...[
                            SizedBox(height: errOffset),
                            _ErrorText(text: _passErr!),
                          ],

                          SizedBox(height: 30.sh),

                          _AnimatedWrapper(
                            animation: _staggeredAnimations[6],
                            child: Center(
                              child: Column(
                                children: [
                                  Text(
                                    "By registering you agree to our",
                                    style: TextStyle(
                                      color: purple, fontSize: 12.sp, fontWeight: FontWeight.w500,
                                      letterSpacing: 0.2, fontFamily: "Satoshi",
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const TermsAndConditionScreen(viewOnly: true),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      "Terms and Conditions",
                                      style: TextStyle(
                                        color: purple, fontSize: 12.sp, fontWeight: FontWeight.w900,
                                        letterSpacing: 0.2, fontFamily: "Satoshi",
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          SizedBox(height: 40.sh),

                          _AnimatedWrapper(
                            animation: _staggeredAnimations[7],
                            child: GestureDetector(
                              onTap: _onNext,
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
                                            width: 18.sw, height: 18.sw,
                                            child: const CircularProgressIndicator(strokeWidth: 2, color: btnText),
                                          ),
                                          SizedBox(width: 10.sw),
                                          Text(
                                            "Next...",
                                            style: TextStyle(
                                              color: btnText, fontSize: 12.sp,
                                              fontWeight: FontWeight.bold, fontFamily: "Satoshi",
                                            ),
                                          ),
                                        ],
                                      )
                                    : Text(
                                        "Next",
                                        style: TextStyle(
                                          color: btnText, fontSize: 12.sp,
                                          fontWeight: FontWeight.bold, fontFamily: "Satoshi",
                                        ),
                                      ),
                              ),
                            ),
                          ),

                          SizedBox(height: 20.sh),

                          _AnimatedWrapper(
                            animation: _staggeredAnimations[8],
                            child: Center(
                              child: Text(
                                "Or register with",
                                style: TextStyle(
                                  color: purple, fontSize: 12.sp, fontWeight: FontWeight.w500,
                                  letterSpacing: 0.2, fontFamily: "Satoshi",
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: 20.sh),

                          _AnimatedWrapper(
                            animation: _staggeredAnimations[9],
                            child: Row(
                              children: [
                                Expanded(
                                  child: _SocialBtn(
                                    icon: "assets/logos/google.png",
                                    iconW: 48.sw, iconH: 27.sh,
                                    onTap: _onGoogleLogin,
                                  ),
                                ),
                                SizedBox(width: 12.sw),
                                Expanded(
                                  child: _SocialBtn(
                                    icon: "assets/logos/apple.png",
                                    iconW: 70.sw, iconH: 44.sh,
                                    onTap: _onAppleLogin,
                                  ),
                                ),
                              ],
                            ),
                          ),
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

class _SocialBtn extends StatelessWidget {
  final String icon;
  final double iconW, iconH;
  final VoidCallback onTap;
  const _SocialBtn({required this.icon, required this.iconW, required this.iconH, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 59.sh,
        decoration: BoxDecoration(
          color: const Color(0xFFF9E3D5).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(15.sw),
          border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1),
        ),
        alignment: Alignment.center,
        child: Image.asset(icon, width: iconW, height: iconH, fit: BoxFit.contain),
      ),
    );
  }
}



