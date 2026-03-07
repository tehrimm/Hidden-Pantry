// lib/screens/Authorization/forget_password_phone.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:country_code_picker/country_code_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
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

class _ForgetPasswordPhoneScreenState extends State<ForgetPasswordPhoneScreen> {
  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
  }
  // ===== Colors (same palette) =====
  static const Color bg = Color(0xFFFFF3EB);
  static const Color purple = Color(0xFF462F4D);
  static const Color hint = Color(0xFFBFA89A);

  static const Color fieldBg = Color(0xFFFDECE4);

  static const Color orange = Color(0xFFF2894F);
  static const Color btnText = Color(0xFFFFF2EA);

  final TextEditingController _phoneCtrl = TextEditingController();

  bool _loading = false;

  // Default Pakistan
  String _dialCode = "+92";

  // Field error (red text below)
  String? _err;

  // Anti-spam cooldown (prevents too-many-requests / unusual activity)
  DateTime? _nextAllowedAt;
  Timer? _cooldownTimer;
  int _cooldownLeft = 0;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ===== Responsive scaling =====
  double _scale(BuildContext context, double v) {
    final size = MediaQuery.of(context).size;
    final base = math.min(size.width / 393.0, size.height / 852.0);
    final clamped = base.clamp(0.85, 1.20);
    return v * clamped;
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

  /// Builds correct E.164 number
  /// Example: dial +92, input "03001234567" -> "+923001234567"
  String _buildE164() {
    var raw = _phoneCtrl.text.trim();
    raw = raw.replaceAll(RegExp(r'\s+'), '');
    raw = raw.replaceAll(RegExp(r'[^0-9]'), '');

    // Remove leading 0(s) (very common in PK: 03xxxxxxxxx)
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
    debugPrint("verify pressed");

    if (_loading) return;

    // Anti-spam
    if (_inCooldown()) {
      _snack("Please wait $_cooldownLeft seconds before trying again.");
      return;
    }

    if (!_validate()) return;

    final phone = _buildE164();
    debugPrint("verifyPhoneNumber -> $phone");

    setState(() {
      _loading = true;
      _err = null;
    });

    // Start cooldown immediately (prevents repeat taps & unusual activity blocks)
    _startCooldown(60);

    try {
      await _authService.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),

        verificationCompleted: (PhoneAuthCredential credential) {
          debugPrint("verificationCompleted (auto)");
          // Don't auto sign in for reset password.
        },

        verificationFailed: (FirebaseAuthException e) {
          debugPrint("verificationFailed: ${e.code} | ${e.message}");
          if (!mounted) return;
          setState(() {
            _loading = false;
            _err = _friendlyAuthError(e);
          });
          _snack(_err!);
        },

        codeSent: (String verificationId, int? resendToken) {
          debugPrint("codeSent");
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

        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint("codeAutoRetrievalTimeout");
        },
      );
    } catch (e) {
      debugPrint("exception: $e");
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
    final mq = MediaQuery.of(context);
    final s = (double v) => _scale(context, v);

    return Scaffold(
      backgroundColor: bg,
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          top: false,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(s(30)),
            child: Stack(
              children: [
                const PatternBackground(),

                // Main scroll content
                SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: s(30),
                    right: s(30),
                    top: mq.padding.top + s(51),
                    bottom: s(14) + mq.padding.bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back
                    BackButtonWidget(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ForgetPasswordScreen(),
                          ),
                        );
                      },
                    ),

                      SizedBox(height: s(38)),

                      SizedBox(
                        width: s(235),
                        child: Text(
                          "Reset\nPassword",
                          style: TextStyle(
                            color: purple,
                            fontSize: s(40),
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                            fontFamily: "Satoshi",
                          ),
                        ),
                      ),

                      SizedBox(height: s(18)),

                      SizedBox(
                        width: s(260),
                        child: Text(
                          "Please enter your phone number to reset the password",
                          style: TextStyle(
                            color: purple,
                            fontSize: s(15),
                            fontFamily: "Satoshi",
                          ),
                        ),
                      ),

                      SizedBox(height: s(26)),

                      // Phone field
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: s(70),
                            decoration: BoxDecoration(
                              color: _err == null
                                  ? fieldBg
                                  : const Color(0xFFFFE0DD),
                              borderRadius: BorderRadius.circular(s(20)),
                            ),
                            child: Row(
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(left: s(12)),
                                  child: CountryCodePicker(
                                    onChanged: (code) {
                                      setState(() {
                                        _dialCode =
                                            code.dialCode ?? _dialCode;
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
                                      fontSize: s(12),
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
                                  height: s(36),
                                  color: const Color(0xFFEAD2C6),
                                ),

                                SizedBox(width: s(12)),

                                Expanded(
                                  child: TextField(
                                    controller: _phoneCtrl,
                                    keyboardType: TextInputType.phone,
                                    cursorColor: purple,
                                    style: TextStyle(
                                      color: purple,
                                      fontSize: s(12),
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                      fontFamily: "Satoshi",
                                    ),
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      hintText: "Phone Number",
                                      hintStyle: TextStyle(
                                        color: hint,
                                        fontSize: s(12),
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.2,
                                        fontFamily: "Satoshi",
                                      ),
                                      contentPadding: EdgeInsets.symmetric(
                                        vertical: s(20),
                                      ),
                                    ),
                                  ),
                                ),

                                SizedBox(width: s(12)),
                              ],
                            ),
                          ),

                          if (_err != null) ...[
                            SizedBox(height: s(6)),
                            Text(
                              _err!,
                              style: TextStyle(
                                color: const Color(0xFFFD3250),
                                fontSize: s(10),
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.2,
                                fontFamily: "Satoshi",
                              ),
                            ),
                          ],

                          if (_inCooldown()) ...[
                            SizedBox(height: s(8)),
                            Text(
                              "Try again in $_cooldownLeft seconds",
                              style: TextStyle(
                                color: hint,
                                fontSize: s(11),
                                fontWeight: FontWeight.w600,
                                fontFamily: "Satoshi",
                              ),
                            ),
                          ],
                        ],
                      ),

                      SizedBox(height: s(40)),

                      // Next button
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: (_loading || _inCooldown())
                              ? null
                              : _verifyPhoneNumber,
                          child: Opacity(
                            opacity: (_loading || _inCooldown()) ? 0.7 : 1,
                            child: Container(
                              width: s(221),
                              height: s(62),
                              decoration: BoxDecoration(
                                color: orange,
                                borderRadius: BorderRadius.circular(s(20)),
                              ),
                              alignment: Alignment.center,
                              child: _loading
                                  ? SizedBox(
                                      width: s(18),
                                      height: s(18),
                                      child: const CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _inCooldown() ? "Wait..." : "Next",
                                          style: TextStyle(
                                            color: btnText,
                                            fontSize: s(12),
                                            fontWeight: FontWeight.bold,
                                            fontFamily: "Satoshi",
                                          ),
                                        ),
                                        SizedBox(width: s(8)),
                                        Icon(
                                          Icons.arrow_forward_ios,
                                          size: s(12),
                                          color: btnText,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: s(14)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



