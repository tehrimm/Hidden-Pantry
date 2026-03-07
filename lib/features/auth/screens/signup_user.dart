import 'dart:math' as math;
import 'package:flutter/material.dart';

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

class SignupUserScreen extends StatefulWidget {
  final AuthService? authService;
  final UserService? userService;
  const SignupUserScreen({super.key, this.authService, this.userService});

  @override
  State<SignupUserScreen> createState() => _SignupUserScreenState();
}

class _SignupUserScreenState extends State<SignupUserScreen> {
  late final AuthService _authService;
  late final UserService _userService;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _userService = widget.userService ?? UserService();
  }

  // Controllers
  final _fullNameCtrl = TextEditingController();
  final _gmailCtrl = TextEditingController(); // username only
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  // UI
  bool _obscurePassword = true;
  bool _loading = false;

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

  // Base size
  static const double _baseW = 393;
  static const double _baseH = 852;


  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _gmailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
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
      _gmailErr = AuthValidator.validateEmail(gmailUser);
      _phoneErr = AuthValidator.validatePhone(phoneDigits);
      _passErr = AuthValidator.validatePassword(pass);
    });

    if (_gmailErr == "*email field is required") {
      _gmailErr = "*field is required";
    }

    if (_nameErr != null || _gmailErr != null || _phoneErr != null || _passErr != null) {
      if (_gmailErr != null) {
        _snack("Gmail Error: $_gmailErr");
      } else if (_nameErr != null) {
        _snack("Name Error: $_nameErr");
      } else if (_phoneErr != null) {
        _snack("Phone Error: $_phoneErr");
      } else if (_passErr != null) {
        _snack("Password Error: $_passErr");
      }
      return false;
    }
    return true;
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
    debugPrint("_onRegister called");

    if (_loading) {
      debugPrint("Already loading, ignoring tap");
      return;
    }

    if (!_validate()) {
      debugPrint("Validation returned false");
      return;
    }

    final email = _gmailCtrl.text.trim();
    
    // Normalizing phone (exactly like login)
    var rawPhone = _phoneCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (rawPhone.startsWith('0')) {
      rawPhone = rawPhone.replaceFirst(RegExp(r'^0+'), '');
    }
    final phone = "$_countryCode$rawPhone";

    final fullName = _fullNameCtrl.text.trim();
    final pass = _passwordCtrl.text.trim();

    debugPrint("Attempting Register: $email");

    _setLoading(true);

    try {
      // 1) Auth create
      debugPrint("Creating user in Firebase Auth...");
      final cred = await _authService.registerWithEmail(email, pass);
      debugPrint("Auth success: ${cred?.user?.uid}");

      // 2) Firestore save (don’t block user forever)
      try {
        debugPrint("Saving profile to Firestore...");
        await _userService
            .upsertCurrentUserProfile(
              fullName: fullName,
              phoneNumber: phone,
              allergies: const [],
            )
            .timeout(const Duration(seconds: 5), onTimeout: () {
          debugPrint("Firestore save timed out - proceeding optimistically");
        });
        debugPrint("Firestore save success (or timeout skipped)");
      } catch (e) {
        debugPrint("Profile save error (ignoring to unblock user): $e");
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AllergiesScreen(userService: _userService)),
      );
    } on FirebaseAuthException catch (e) {
      debugPrint("FirebaseAuthException: ${e.code} / ${e.message}");

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

      // show message if it’s not one of the field-mapped errors
        if (e.code != "email-already-in-use" &&
            e.code != "weak-password" &&
            e.code != "invalid-email") {
          _snack("${e.message ?? "Signup failed"}", isError: true);
      }
    } catch (e) {
      debugPrint("Generic Error: $e");
      if (mounted) _snack("Signup error: $e", isError: true);
    } finally {
      if (mounted) _setLoading(false);
    }
  }

  Future<void> _onGoogleRegister() async {
    _setLoading(true);

    UserCredential? cred;
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        _setLoading(false);
        return;
      }

      final googleAuth = await googleUser.authentication;

      final googleCredential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      cred = await FirebaseAuth.instance.signInWithCredential(googleCredential);

      final user = cred.user!;
      
      // Normalizing phone (exactly like email signup)
      var rawPhone = _phoneCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
      if (rawPhone.startsWith('0')) {
        rawPhone = rawPhone.replaceFirst(RegExp(r'^0+'), '');
      }
      final phone = "$_countryCode$rawPhone";

      final fullName = (user.displayName ?? _fullNameCtrl.text.trim()).trim();

      await _userService.upsertCurrentUserProfile(
        fullName: fullName.isEmpty ? "User" : fullName,
        phoneNumber: phone,
        allergies: const [],
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AllergiesScreen()),
      );
    } catch (e) {
      debugPrint("Google signup failed: $e");
      // rollback if auth happened but firestore failed
      try {
        await cred?.user?.delete();
      } catch (_) {}
      if (mounted) _snack("Google signup failed", isError: true);
    } finally {
      if (mounted) _setLoading(false);
    }
  }

  Future<void> _onAppleRegister() async {
    _setLoading(true);

    UserCredential? cred;
    try {
      final apple = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final appleCredential = OAuthProvider("apple.com").credential(
        idToken: apple.identityToken,
        accessToken: apple.authorizationCode,
      );

      cred = await FirebaseAuth.instance.signInWithCredential(appleCredential);

      final user = cred.user!;

      // Normalizing phone (exactly like email signup)
      var rawPhone = _phoneCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
      if (rawPhone.startsWith('0')) {
        rawPhone = rawPhone.replaceFirst(RegExp(r'^0+'), '');
      }
      final phone = "$_countryCode$rawPhone";

      final appleName = [
        apple.givenName ?? "",
        apple.familyName ?? "",
      ].where((e) => e.trim().isNotEmpty).join(" ").trim();

      final fullName = (appleName.isNotEmpty
              ? appleName
              : (user.displayName ?? _fullNameCtrl.text.trim()))
          .trim();

      await _userService.upsertCurrentUserProfile(
        fullName: fullName.isEmpty ? "User" : fullName,
        phoneNumber: phone,
        allergies: const [],
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AllergiesScreen()),
      );
    } catch (e) {
      debugPrint("Apple signup failed: $e");
      try {
        await cred?.user?.delete();
      } catch (_) {}
      if (mounted) _snack("Apple signup failed", isError: true);
    } finally {
      if (mounted) _setLoading(false);
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

    // ---- spacing rules you asked for ----
    final fieldH = sy(70);

    final baseGap = sy(16); // normal gap between boxes

    final errOffset = sy(4); // error text starts 4px under box

    // base top positions (keep your original layout start)

    // each next top = prev box + 16 + (+10 if previous has error)
    // removed unused topPass

    // text padding to keep vertical centering like Figma
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
                                  MaterialPageRoute(builder: (_) => const UserLoginScreen()),
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
                            // No need for absolute height here, let it flow
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldBox(
                                  width: sx(332),
                                  height: fieldH,
                                  isError: _nameErr != null,
                                  child: TextField(
                                    key: const Key('signup_full_name'),
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

                          // ================= GMAIL ROW =================
                          SizedBox(
                            width: sx(332),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldBox(
                                  width: sx(332),
                                  height: fieldH,
                                  isError: _gmailErr != null,
                                  child: TextField(
                                    key: const Key('signup_gmail'),
                                    controller: _gmailCtrl,
                                    onChanged: (_) => setState(() {}),
                                    cursorColor: purple,
                                    textAlignVertical: TextAlignVertical.center,
                                    style: TextStyle(
                                      color: (_gmailErr != null)
                                          ? errText
                                          : (_gmailCtrl.text.trim().isEmpty
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
                                if (_gmailErr != null) ...[
                                  SizedBox(height: errOffset),
                                  Padding(
                                    padding: EdgeInsets.only(left: sx(11)),
                                    child: Text(
                                      _gmailErr!,
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
                                          showDropDownButton: false, // no arrow
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
                                          key: const Key('signup_phone'),
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
                                          key: const Key('signup_password'),
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
                                            const TermsAndConditionScreen(viewOnly: true),
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

                          // Register button
                          GestureDetector(
                            onTap: () {
                              debugPrint("🖱️ Register Button Tapped");
                              if (_loading) return;
                              _onRegister();
                            },
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
                                      "Register",
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
                                  onTap: _loading ? null : _onGoogleRegister,
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
                                  onTap: _loading ? null : _onAppleRegister,
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
