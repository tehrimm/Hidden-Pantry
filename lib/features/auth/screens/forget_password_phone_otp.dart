// lib/screens/Authorization/forget_password_phone_otp.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_user.dart';
import 'package:hidden_pantry_app/core/widgets/main_navigation_shell.dart';
import 'forget_password_phone.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
 // back goes to phone screen (change if needed)

class ForgetPasswordPhoneOtpScreen extends StatefulWidget {
  final String phone; // e.g. +923133131313
  final String verificationId;
  const ForgetPasswordPhoneOtpScreen({
    super.key,
    required this.phone,
    required this.verificationId,
  });

  @override
  State<ForgetPasswordPhoneOtpScreen> createState() =>
      _ForgetPasswordPhoneOtpScreenState();
}

class _ForgetPasswordPhoneOtpScreenState
    extends State<ForgetPasswordPhoneOtpScreen> {
  // Colors (from your UI)
  static const Color bg = Color(0xFFFFF3EB);
  static const Color purple = Color(0xFF462F4D);
  static const Color brown = Color(0xFF74503C);

  static const Color orange = Color(0xFFF2894F);
  static const Color btnText = Color(0xFFFFF2EA);
  static const Color resendRed = Color(0xFFFD3250);

  final List<TextEditingController> _ctrl =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focus = List.generate(6, (_) => FocusNode());

  bool _loading = false;

  @override
  void dispose() {
    for (final c in _ctrl) {
      c.dispose();
    }
    for (final f in _focus) {
      f.dispose();
    }
    super.dispose();
  }

  double _scale(BuildContext context, double v) {
    final size = MediaQuery.of(context).size;
    final base = math.min(size.width / 393.0, size.height / 852.0);
    final clamped = base.clamp(0.85, 1.20);
    return v * clamped;
  }

  String get _otp =>
      _ctrl.map((e) => e.text.trim()).join(); // "123456"

  bool get _otpComplete => _otp.length == 6 && !_otp.contains(RegExp(r'\D'));

  void _setLoading(bool v) {
    if (!mounted) return;
    setState(() => _loading = v);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _onChanged(int i, String v) {
    final value = v.trim();

    // If user pasted multiple digits, spread them
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '').split('');
      if (digits.isEmpty) return;

      int idx = i;
      for (final d in digits) {
        if (idx >= 6) break;
        _ctrl[idx].text = d;
        idx++;
      }
      if (idx < 6) {
        _focus[idx].requestFocus();
      } else {
        FocusScope.of(context).unfocus();
      }
      setState(() {});
      return;
    }

    if (value.isNotEmpty) {
      // Move next
      if (i < 5) _focus[i + 1].requestFocus();
      setState(() {});
    }
  }

  void _onBackspace(int i) {
    if (_ctrl[i].text.isNotEmpty) {
      _ctrl[i].clear();
      setState(() {});
      return;
    }
    if (i > 0) {
      _focus[i - 1].requestFocus();
      _ctrl[i - 1].clear();
      setState(() {});
    }
  }

  Future<void> _verify() async {
    if (!_otpComplete) {
      _snack("Enter complete OTP");
      return;
    }

    _setLoading(true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: _otp,
      );

      // We sign in (this links/proves identity)
      final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCred.user;

      if (user != null) {
        try {
          // 1. Find if ANY document in 'users' has this phone number
          debugPrint("Searching Firestore for phone: ${widget.phone}");
          
          // Try exact match first
          var query = await FirebaseFirestore.instance
              .collection("users")
              .where("phone", isEqualTo: widget.phone)
              .get();

          // If not found, try common variant (adding/removing leading 0 after code)
          if (query.docs.isEmpty) {
            String altPhone;
            if (widget.phone.contains(RegExp(r'\+\d+0'))) {
              // try removing the extra 0: +9203 -> +923
              altPhone = widget.phone.replaceFirst("0", "", widget.phone.indexOf(RegExp(r'\d')) + 1);
            } else {
              // try adding the extra 0: +923 -> +9203
              final match = RegExp(r'\+\d+').firstMatch(widget.phone);
              if (match != null) {
                altPhone = widget.phone.replaceFirst(match.group(0)!, "${match.group(0)}0");
              } else {
                altPhone = widget.phone;
              }
            }
            if (altPhone != widget.phone) {
              debugPrint("Trying alternative phone: $altPhone");
              query = await FirebaseFirestore.instance
                  .collection("users")
                  .where("phone", isEqualTo: altPhone)
                  .get();
            }
          }

          if (query.docs.isEmpty) {
            debugPrint("CRITICAL: No user document found for ${widget.phone}. Sign-out triggered.");
            await FirebaseAuth.instance.signOut();
            _snack("Account does not exist. Please sign up first.");
            return;
          }

          // 2. Check the UID of the matching document
          final existingDoc = query.docs.first;
          final String dbUid = existingDoc.id;
          final String authUid = user.uid;

          debugPrint("Auth UID: $authUid");
          debugPrint("DB Doc ID: $dbUid");

          if (dbUid != authUid) {
            debugPrint("IDENTITY MISMATCH DETECTED");
            
            // OPTION B: Identity Verified! Now help them reset their Email Password.
            final String? email = existingDoc.data()['email'];
            
            if (email != null && email.isNotEmpty) {
              _snack("Identity Verified! Sending password reset link to $email...");
              
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                
                if (mounted) {
                   Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserLoginScreen(),
                    ),
                    (route) => false,
                  );
                  _snack("Reset link sent! Please reset your password and login.");
                }
              } catch (e) {
                debugPrint("Failed to send reset email: $e");
                _snack("Verified, but could not send reset link. Try Email Reset instead.");
              }
            } else {
              _snack("Verified, but no email found for this account. Contact support.");
            }

            await FirebaseAuth.instance.signOut();
            return;
          }

          debugPrint("IDENTITY MATCH CONFIRMED");

          // 3. Success! Phone UID matches DB UID
          _snack("Login Successful!");
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const MainNavigationShell()),
              (route) => false,
            );
          }
        } catch (e) {
          debugPrint("Firestore Error: $e");
          await FirebaseAuth.instance.signOut();
          if (e.toString().contains("permission-denied")) {
            _snack("Database Error: Missing permissions to search users.");
          } else {
            _snack("Login failed: $e");
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      _snack(e.message ?? "Verification failed");
    } catch (e) {
      _snack("Something went wrong: $e");
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _resend() async {
    if (_loading) return;
    _snack("Resend OTP tapped");
    // Later: trigger resend OTP logic
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final s = (double v) => _scale(context, v);

    final boxW = s(44);
    final boxH = s(51);

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

                // Content (scroll-safe)
                SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: s(30),
                    right: s(30),
                    top: mq.padding.top + s(22),
                    bottom: s(22) + mq.viewInsets.bottom,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          mq.size.height - mq.padding.top - mq.padding.bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BackButtonWidget(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ForgetPasswordPhoneScreen(),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: s(38)),

                        // Title
                        SizedBox(
                          width: s(235),
                          child: Text(
                            "Enter OTP",
                            style: TextStyle(
                              color: purple,
                              fontSize: s(40),
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                              fontFamily: "Satoshi",
                            ),
                          ),
                        ),

                        SizedBox(height: s(12)),

                        // Subtitle
                        SizedBox(
                          width: s(300),
                          child: Text(
                            "Please enter the OTP sent to ${widget.phone}",
                            style: TextStyle(
                              color: purple,
                              fontSize: s(15),
                              fontFamily: "Satoshi",
                            ),
                          ),
                        ),

                        SizedBox(height: s(26)),

                        // OTP Boxes (responsive, no overflow)
                        LayoutBuilder(
                          builder: (context, c) {
                            final totalW = boxW * 6 + s(10) * 5;
                            final shouldWrap = totalW > c.maxWidth;

                            final boxes = List.generate(6, (i) {
                              return _OtpBox(
                                width: boxW,
                                height: boxH,
                                brown: brown,
                                purple: purple,
                                controller: _ctrl[i],
                                focusNode: _focus[i],
                                onChanged: (v) => _onChanged(i, v),
                                onBackspace: () => _onBackspace(i),
                              );
                            });

                            if (shouldWrap) {
                              return Wrap(
                                spacing: s(10),
                                runSpacing: s(10),
                                children: boxes,
                              );
                            }

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (int i = 0; i < boxes.length; i++) ...[
                                  if (i != 0) SizedBox(width: s(10)),
                                  boxes[i],
                                ],
                              ],
                            );
                          },
                        ),

                        SizedBox(height: s(26)),

                        // Verify button (full width like UI)
                        GestureDetector(
                          onTap: _loading ? null : _verify,
                          child: Container(
                            width: double.infinity,
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
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    "Verify Code",
                                    style: TextStyle(
                                      color: btnText,
                                      fontSize: s(12),
                                      fontWeight: FontWeight.bold,
                                      fontFamily: "Satoshi",
                                    ),
                                  ),
                          ),
                        ),

                        SizedBox(height: s(18)),

                        // Resend text
                        Center(
                          child: GestureDetector(
                            onTap: _resend,
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  color: purple,
                                  fontSize: s(15),
                                  fontFamily: "Satoshi",
                                ),
                                children: const [
                                  TextSpan(text: "Haven’t got the OTP yet? "),
                                  TextSpan(
                                    text: "Resend OTP",
                                    style: TextStyle(color: resendRed),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: s(40)),
                        SizedBox(height: s(8)),
                      ],
                    ),
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

class _OtpBox extends StatelessWidget {
  final double width;
  final double height;
  final Color brown;
  final Color purple;
  final TextEditingController controller;
  final FocusNode focusNode;

  final ValueChanged<String> onChanged;
  final VoidCallback onBackspace;

  const _OtpBox({
    required this.width,
    required this.height,
    required this.brown,
    required this.purple,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: KeyboardListener(
        focusNode: FocusNode(skipTraversal: true),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace) {
            onBackspace();
          }
        },
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          cursorColor: purple,
          style: TextStyle(
            color: purple,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            fontFamily: "Satoshi",
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(1),
          ],
          decoration: InputDecoration(
            counterText: "",
            filled: false,
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(width: 0.5, color: brown),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(width: 0.5, color: brown),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(width: 1.0, color: brown),
            ),
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}



