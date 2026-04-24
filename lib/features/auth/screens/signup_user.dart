import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:country_code_picker/country_code_picker.dart';

import 'package:hidden_pantry_app/features/onboarding/screens/terms_and_condition.dart';
import 'package:hidden_pantry_app/features/onboarding/screens/loading_five.dart';
import 'login_user.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:hidden_pantry_app/features/user/services/user_service.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';
import 'package:hidden_pantry_app/features/recipes/screens/allergies.dart';
import 'package:hidden_pantry_app/core/utils/auth_validator.dart';

import 'package:hidden_pantry_app/core/services/auth_service.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';

class SignupUserScreen extends StatefulWidget {
  final AuthService? authService;
  final UserService? userService;
  const SignupUserScreen({super.key, this.authService, this.userService});

  @override
  State<SignupUserScreen> createState() => _SignupUserScreenState();
}

class _SignupUserScreenState extends State<SignupUserScreen> with TickerProviderStateMixin {
  late final AuthService _authService;
  late final UserService _userService;

  // Animations
  late AnimationController _mainController;
  late List<Animation<double>> _staggeredAnimations;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _userService = widget.userService ?? UserService();

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

  // Controllers
  final _fullNameCtrl = TextEditingController();
  final _gmailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  // UI
  bool _obscurePassword = true;
  bool _loading = false;
  bool _agreed = false;

  // Errors
  String? _nameErr;
  String? _gmailErr;
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

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _gmailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _mainController.dispose();
    super.dispose();
  }

  // ---------------- VALIDATION ----------------
  bool _validate() {
    final name = _fullNameCtrl.text.trim();
    final gmailUser = _gmailCtrl.text.trim();
    final phoneDigits = _phoneCtrl.text.replaceAll(RegExp(r"\D"), "");
    final pass = _passwordCtrl.text;

    setState(() {
      _nameErr = AuthValidator.validateFullName(name);
      if (gmailUser.contains('@')) {
        _gmailErr = AuthValidator.validateEmail(gmailUser);
      } else {
        _gmailErr = gmailUser.isEmpty
            ? "*field is required"
            : (RegExp(r'^[a-zA-Z0-9._%+-]+$').hasMatch(gmailUser) ? null : "*enter valid email");
      }
      _phoneErr = AuthValidator.validatePhone(phoneDigits);
      _passErr = AuthValidator.validatePassword(pass);
    });

    if (_gmailErr == "*email field is required") {
      _gmailErr = "*field is required";
    }

    if (!_agreed) {
      _snack("Please agree to the Terms and Conditions", isError: true);
      return false;
    }

    return _nameErr == null && _gmailErr == null && _phoneErr == null && _passErr == null;
  }

  // ---------------- HELPERS ----------------
  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    Toaster.show(context, msg, isError: isError);
  }

  void _setLoading(bool v) {
    if (!mounted) return;
    setState(() => _loading = v);
  }

  void _goLoadingFive() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LoadingFive()),
    );
  }

  // ---------------- EMAIL/PASS SIGNUP ----------------
  Future<void> _onRegister() async {
    if (_loading) return;
    if (!_validate()) return;

    final email = _gmailCtrl.text.trim().contains('@')
        ? _gmailCtrl.text.trim()
        : "${_gmailCtrl.text.trim()}@gmail.com";
    
    var rawPhone = _phoneCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (rawPhone.startsWith('0')) {
      rawPhone = rawPhone.replaceFirst(RegExp(r'^0+'), '');
    }
    final phone = "$_countryCode$rawPhone";

    final fullName = _fullNameCtrl.text.trim();
    final pass = _passwordCtrl.text.trim();

    _setLoading(true);

    try {
      final cred = await _authService.registerWithEmail(email, pass);
      
      if (cred?.user == null) {
        throw FirebaseAuthException(code: "unknown", message: "Failed to create user.");
      }
      
      _userService
          .upsertCurrentUserProfile(
            fullName: fullName,
            phoneNumber: phone,
            allergies: const [],
          )
          .then((_) => debugPrint("Background profile sync complete"))
          .catchError((e) => debugPrint("Background profile sync failed: $e"));

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AllergiesScreen(userService: _userService)),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.code == "email-already-in-use") {
          _gmailErr = "*email already in use";
        } else if (e.code == "weak-password") {
          _passErr = "*password is too weak";
        } else if (e.code == "invalid-email") {
          _gmailErr = "*invalid email";
        }
      });
      if (e.code != "email-already-in-use" &&
          e.code != "weak-password" &&
          e.code != "invalid-email") {
        _snack("${e.message ?? "Signup failed"}", isError: true);
      }
    } catch (e) {
      if (mounted) _snack("Signup error: $e", isError: true);
    } finally {
      if (mounted) _setLoading(false);
    }
  }

  Future<void> _onGoogleRegister() async {
    _snack("Google registration coming soon");
  }

  Future<void> _onAppleRegister() async {
    _snack("Apple registration coming soon");
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    final mq = MediaQuery.of(context);

    final fieldH = 70.sh;
    final baseGap = 16.sh;
    final errOffset = 4.sh;
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
        body: Stack(
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
                              MaterialPageRoute(builder: (_) => const UserLoginScreen()),
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
                              style: TextStyle(
                                color: enabledText,
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
                                contentPadding: EdgeInsets.symmetric(horizontal: 30.sw, vertical: 22.sh),
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
                            isError: _gmailErr != null,
                            child: TextField(
                              controller: _gmailCtrl,
                              onChanged: (_) => setState(() {}),
                              cursorColor: purple,
                              style: TextStyle(
                                color: enabledText,
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
                                contentPadding: EdgeInsets.symmetric(horizontal: 30.sw, vertical: 22.sh),
                              ),
                            ),
                          ),
                        ),
                        if (_gmailErr != null) ...[
                          SizedBox(height: errOffset),
                          _ErrorText(text: _gmailErr!),
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
                                    onChanged: (c) => setState(() => _countryCode = c.dialCode ?? "+92"),
                                    initialSelection: _countryCode,
                                    favorite: const ["+92", "+1"],
                                    alignLeft: true,
                                    padding: EdgeInsets.zero,
                                    showDropDownButton: false,
                                    textStyle: TextStyle(
                                      color: purple,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                      fontFamily: "Satoshi",
                                    ),
                                  ),
                                ),
                                Container(width: 1, height: 36.sh, color: stroke.withValues(alpha: 0.5)),
                                SizedBox(width: 14.sw),
                                Expanded(
                                  child: TextField(
                                    controller: _phoneCtrl,
                                    onChanged: (_) => setState(() {}),
                                    keyboardType: TextInputType.phone,
                                    cursorColor: purple,
                                    style: TextStyle(
                                      color: enabledText,
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
                                      contentPadding: EdgeInsets.symmetric(vertical: 22.sh),
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
                                    style: TextStyle(
                                      color: enabledText,
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
                                      contentPadding: EdgeInsets.symmetric(horizontal: 30.sw, vertical: 22.sh),
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                                  child: Padding(
                                    padding: EdgeInsets.only(right: 16.sw),
                                    child: Icon(
                                      _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                      color: purple.withValues(alpha: 0.6),
                                      size: 20.sw,
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
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10.sw),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () => setState(() => _agreed = !_agreed),
                                  child: Container(
                                    width: 20.sw,
                                    height: 20.sw,
                                    decoration: BoxDecoration(
                                      color: _agreed ? btnOrange : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6.sw),
                                      border: Border.all(
                                        color: _agreed ? btnOrange : purple.withValues(alpha: 0.3),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: _agreed
                                        ? Icon(Icons.check, size: 14.sw, color: Colors.white)
                                        : null,
                                  ),
                                ),
                                SizedBox(width: 12.sw),
                                Expanded(
                                  child: Wrap(
                                    children: [
                                      Text(
                                        "I agree to the ",
                                        style: TextStyle(
                                          color: purple.withValues(alpha: 0.7),
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w500,
                                          fontFamily: "Satoshi",
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
                                            color: purple,
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.w900,
                                            fontFamily: "Satoshi",
                                            decoration: TextDecoration.underline,
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

                        SizedBox(height: 40.sh),

                        _AnimatedWrapper(
                          animation: _staggeredAnimations[7],
                          child: GestureDetector(
                            onTap: _onRegister,
                            child: Container(
                              width: double.infinity,
                              height: 62.sh,
                              decoration: BoxDecoration(
                                color: btnOrange,
                                borderRadius: BorderRadius.circular(20.sw),
                                boxShadow: [
                                  if (!_loading)
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
                                          "Registering...",
                                          style: TextStyle(
                                            color: btnText, fontSize: 12.sp,
                                            fontWeight: FontWeight.bold, fontFamily: "Satoshi",
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      "Register",
                                      style: TextStyle(
                                        color: btnText, fontSize: 12.sp,
                                        fontWeight: FontWeight.bold, fontFamily: "Satoshi",
                                      ),
                                    ),
                            ),
                          ),
                        ),

                        SizedBox(height: 12.sh),

                        _AnimatedWrapper(
                          animation: _staggeredAnimations[8],
                          child: Center(
                            child: Text(
                              "Or register with",
                              style: TextStyle(
                                color: purple.withValues(alpha: 0.6), fontSize: 12.sp,
                                fontWeight: FontWeight.w600, fontFamily: "Satoshi",
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 12.sh),

                        _AnimatedWrapper(
                          animation: _staggeredAnimations[9],
                          child: Row(
                            children: [
                              Expanded(
                                child: _SocialBtn(
                                  icon: "assets/logos/google.png",
                                  iconW: 48.sw, iconH: 27.sh,
                                  onTap: _onGoogleRegister,
                                ),
                              ),
                              SizedBox(width: 16.sw),
                              Expanded(
                                child: _SocialBtn(
                                  icon: "assets/logos/apple.png",
                                  iconW: 70.sw, iconH: 44.sh,
                                  onTap: _onAppleRegister,
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.sw),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            height: 62.sh,
            decoration: BoxDecoration(
              color: const Color(0xFFF9E3D5),
              borderRadius: BorderRadius.circular(20.sw),
              border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
            ),
            alignment: Alignment.center,
            child: Image.asset(icon, width: iconW, height: iconH, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
