import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'login_user.dart';
import 'forget_password.dart'; // go back
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:hidden_pantry_app/core/utils/auth_validator.dart';

import 'package:hidden_pantry_app/core/services/auth_service.dart';

class ForgetPasswordEmailScreen extends StatefulWidget {
  final AuthService? authService;
  const ForgetPasswordEmailScreen({super.key, this.authService});

  @override
  State<ForgetPasswordEmailScreen> createState() =>
      _ForgetPasswordEmailScreenState();
}

class _ForgetPasswordEmailScreenState extends State<ForgetPasswordEmailScreen> {
  late final AuthService _authService;
  final _emailCtrl = TextEditingController();

  bool _loading = false;
  String? _emailErr;

  static const Color bg = Color(0xFFFFF3EB);
  static const Color purple = Color(0xFF462F4D);
  static const Color fieldBg = Color(0xFFFDECE4);
  static const Color orange = Color(0xFFF2894F);
  static const Color btnText = Color(0xFFFFF2EA);
  static const Color hint = Color(0xFFBFA89A);
  static const Color errText = Color(0xFFFD3250);

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
  }

  double _scale(BuildContext context, double v) {
    final size = MediaQuery.of(context).size;
    final base = math.min(size.width / 393.0, size.height / 852.0);
    final clamped = base.clamp(0.85, 1.20);
    return v * clamped;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool _validate() {
    final email = _emailCtrl.text.trim();
    setState(() {
      _emailErr = AuthValidator.validateEmail(email);
    });
    return _emailErr == null;
  }

 Future<void> _sendEmailReset() async {
  if (!_validate()) return;

  setState(() => _loading = true);
  try {
    final email = _emailCtrl.text.trim();

    // Send reset email
    await _authService.sendPasswordResetEmail(email: email);

    // Inform user
    _snack("Reset link sent to $email");

    // Small delay so user can read message
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Navigate back to login screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const UserLoginScreen(),
      ),
    );
  } on FirebaseAuthException catch (e) {
    if (e.code == "invalid-email") {
      setState(() => _emailErr = "*incorrect email");
    } else if (e.code == "user-not-found") {
      _snack("No account found for this email.");
    } else if (e.code == "too-many-requests") {
      _snack("Too many attempts. Try again later.");
    } else {
      _snack(e.message ?? "Failed to send reset email.");
    }
  } catch (_) {
    _snack("Something went wrong. Try again.");
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}


  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final s = (double v) => _scale(context, v);

    return Scaffold(
      backgroundColor: bg,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        top: false,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(s(30)),
          child: Stack(
            children: [
              const PatternBackground(),

              // Tap-catcher behind content

              // Content
              SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: s(30),
                  right: s(30),
                  top: mq.padding.top + s(51),
                  bottom: s(22) + mq.viewInsets.bottom,
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

                    Text(
                      "Verify Email",
                      style: TextStyle(
                        color: purple,
                        fontSize: s(40),
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        fontFamily: "Satoshi",
                      ),
                    ),

                    SizedBox(height: s(12)),

                    SizedBox(
                      width: s(290),
                      child: Text(
                        "Enter your email and we will send you a password reset link.",
                        style: TextStyle(
                          color: purple,
                          fontSize: s(15),
                          fontFamily: "Satoshi",
                        ),
                      ),
                    ),

                    SizedBox(height: s(26)),

                    // Email field
                    Container(
                      height: s(62),
                      decoration: BoxDecoration(
                        color: fieldBg,
                        borderRadius: BorderRadius.circular(s(20)),
                      ),
                      child: Row(
                        children: [
                          SizedBox(width: s(16)),
                          Container(
                            width: s(46),
                            height: s(47),
                            decoration: BoxDecoration(
                              color: orange,
                              borderRadius: BorderRadius.circular(s(10)),
                            ),
                            alignment: Alignment.center,
                            child: Image.asset(
                              "assets/icons/gmail.png",
                              width: s(18),
                              height: s(18),
                              fit: BoxFit.contain,
                            ),
                          ),
                          SizedBox(width: s(12)),
                          Expanded(
                            child: TextField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _sendEmailReset(),
                              cursorColor: purple,
                              style: TextStyle(
                                color: (_emailErr != null) ? errText : purple,
                                fontSize: s(12),
                                fontWeight: FontWeight.w600,
                                fontFamily: "Satoshi",
                              ),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: "Gmail",
                                hintStyle: TextStyle(
                                  color: hint,
                                  fontSize: s(12),
                                  fontWeight: FontWeight.w500,
                                  fontFamily: "Satoshi",
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: s(12)),
                        ],
                      ),
                    ),

                    if (_emailErr != null) ...[
                      SizedBox(height: s(6)),
                      Text(
                        _emailErr!,
                        style: TextStyle(
                          color: errText,
                          fontSize: s(10),
                          fontWeight: FontWeight.w500,
                          fontFamily: "Satoshi",
                        ),
                      ),
                    ],

                    SizedBox(height: s(28)),

                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: _loading ? null : _sendEmailReset,
                        child: Container(
                          width: s(221),
                          height: s(62),
                          decoration: BoxDecoration(
                            color: orange,
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
                                      child: const CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                    SizedBox(width: s(10)),
                                    Text(
                                      "Sending...",
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
                                  "Send Link",
                                  style: TextStyle(
                                    color: btnText,
                                    fontSize: s(12),
                                    fontWeight: FontWeight.bold,
                                    fontFamily: "Satoshi",
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
    );
  }
}



