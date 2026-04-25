

import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:hidden_pantry_app/core/utils/glass_dialog.dart';
import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';


import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';

import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'nutritionist_pending_screen.dart';
import 'package:hidden_pantry_app/features/nutritionist/services/nutritionist_service.dart';
import 'login_nutritionist.dart';

class SignupNutritionistStep2 extends StatefulWidget {
  final String fullName;
  final String email;
  final String phoneNumber;
  final String? password;

  const SignupNutritionistStep2({
    super.key,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    this.password,
  });

  @override
  State<SignupNutritionistStep2> createState() => _SignupNutritionistStep2State();
}

class _SignupNutritionistStep2State extends State<SignupNutritionistStep2> with TickerProviderStateMixin {
  final NutritionistService _nutritionistService = NutritionistService();

  // Controllers
  final _licenseCtrl = TextEditingController();
  final _organizationCtrl = TextEditingController();
  final _expiryDateCtrl = TextEditingController();

  // UI
  bool _loading = false;

  // Errors
  String? _licenseErr;
  String? _organizationErr;
  String? _expiryErr;
  String? _certErr;

  // Certificate
  File? _certificateFile;
  String? _certificateFileName;

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
      duration: const Duration(milliseconds: 1400),
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
    _licenseCtrl.dispose();
    _organizationCtrl.dispose();
    _expiryDateCtrl.dispose();
    _mainController.dispose();
    super.dispose();
  }

  // ---------------- VALIDATION ----------------
  bool _validate() {
    _licenseErr = _organizationErr = _expiryErr = _certErr = null;

    final license = _licenseCtrl.text.trim();
    final organization = _organizationCtrl.text.trim();
    final expiry = _expiryDateCtrl.text.trim();

    bool ok = true;

    if (license.isEmpty || license.length < 5) {
      _licenseErr = "*invalid license number";
      ok = false;
    }

    if (organization.isEmpty || organization.length < 3) {
      _organizationErr = "*invalid organization name";
      ok = false;
    }

    if (expiry.isEmpty) {
      _expiryErr = "*expiry date required";
      ok = false;
    } else {
      final datePattern = RegExp(r'^\d{1,2}/\d{1,2}/\d{4}$');
      if (!datePattern.hasMatch(expiry)) {
        _expiryErr = "*invalid date format (MM/DD/YYYY)";
        ok = false;
      }
    }

    if (_certificateFile == null) {
      _certErr = "*certificate required";
      ok = false;
    }

    setState(() {});
    return ok;
  }

  // ---------------- HELPERS ----------------
  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _setLoading(bool v) {
    if (!mounted) return;
    setState(() => _loading = v);
  }

  // ---------------- CERTIFICATE UPLOAD ----------------
  Future<void> _pickCertificate() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _certificateFile = File(result.files.single.path!);
          _certificateFileName = result.files.single.name;
          _certErr = null;
        });
      }
    } catch (e) {
      _snack("Error picking file: $e");
    }
  }

  // ---------------- REGISTRATION ----------------
  Future<void> _onRegister() async {
    if (_loading) return;
    if (!_validate()) return;

    final license = _licenseCtrl.text.trim();
    final organization = _organizationCtrl.text.trim();
    final expiryDate = _expiryDateCtrl.text.trim();

    _setLoading(true);

    try {
      User? user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (widget.password == null) throw Exception("Missing authentication context");
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: widget.email,
          password: widget.password!,
        );
        user = cred.user;
      }

      if (user == null) throw Exception("Authentication failed");

      final certificateUrl = await _nutritionistService.uploadCertificate(
        _certificateFile!,
        user.uid,
      );
      
      await _nutritionistService.createNutritionistProfile(
        fullName: widget.fullName,
        email: widget.email,
        phoneNumber: widget.phoneNumber,
        licenseNumber: license,
        certificateUrl: certificateUrl,
        organizationName: organization,
        expiryDate: expiryDate,
      );

      if (!mounted) return;

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        
        await GlassDialog.show(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: bg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.sw)),
            title: Text("Certificate Submitted", style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontFamily: "Satoshi")),
            content: Text("Your certificate has been sent for approval. You will be notified once it's reviewed.", style: TextStyle(color: purple, fontFamily: "Satoshi")),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("OK", style: TextStyle(color: btnOrange, fontWeight: FontWeight.bold, fontFamily: "Satoshi")),
              ),
            ],
          ),
        );

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const NutritionistPendingScreen()),
        );
      });

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String errorMsg = "Signup failed";
      if (e.code == "email-already-in-use") errorMsg = "Email already in use";
      else if (e.code == "weak-password") errorMsg = "Password is too weak";
      else if (e.code == "invalid-email") errorMsg = "Invalid email";
      _snack(errorMsg);
    } catch (e) {
      if (mounted) _snack("Signup error: $e");
    } finally {
      if (mounted) _setLoading(false);
    }
  }

  // ---------------- DATE PICKER ----------------
  Future<void> _selectExpiryDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: btnOrange,
              onPrimary: Colors.white,
              onSurface: purple,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _expiryDateCtrl.text = "${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}/${picked.year}";
        _expiryErr = null;
      });
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

    return PopScope(
      canPop: true,
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

                  Column(
                    children: [
                      _AnimatedWrapper(
                        animation: _staggeredAnimations[0],
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(30.sw, topPad + 36.sh, 30.sw, 20.sh),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const BackButtonWidget(),
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
                            child: GestureDetector(
                              onTap: _pickCertificate,
                              child: _GlassField(
                                height: 70.sh,
                                isError: _certErr != null,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.upload_file_rounded,
                                      color: _certErr != null ? errText : btnOrange,
                                      size: 24.sw,
                                    ),
                                    SizedBox(width: 12.sw),
                                    Flexible(
                                      child: Text(
                                        _certificateFileName ?? "Upload Certificate",
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: _certErr != null ? errText : btnOrange,
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: "Satoshi",
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (_certErr != null) ...[
                            SizedBox(height: 4.sh),
                            _ErrorText(text: _certErr!),
                          ],

                          SizedBox(height: baseGap),

                          _AnimatedWrapper(
                            animation: _staggeredAnimations[3],
                            child: _GlassField(
                              height: fieldH,
                              isError: _licenseErr != null,
                              child: TextField(
                                controller: _licenseCtrl,
                                onChanged: (_) => setState(() {}),
                                cursorColor: purple,
                                textAlignVertical: TextAlignVertical.center,
                                style: TextStyle(
                                  color: (_licenseErr != null) ? errText : enabledText,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                  fontFamily: "Satoshi",
                                ),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: "License Number",
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
                          if (_licenseErr != null) ...[
                            SizedBox(height: errOffset),
                            _ErrorText(text: _licenseErr!),
                          ],

                          SizedBox(height: baseGap),

                          _AnimatedWrapper(
                            animation: _staggeredAnimations[4],
                            child: _GlassField(
                              height: fieldH,
                              isError: _organizationErr != null,
                              child: TextField(
                                controller: _organizationCtrl,
                                onChanged: (_) => setState(() {}),
                                cursorColor: purple,
                                textAlignVertical: TextAlignVertical.center,
                                style: TextStyle(
                                  color: (_organizationErr != null) ? errText : enabledText,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                  fontFamily: "Satoshi",
                                ),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: "Organization Name",
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
                          if (_organizationErr != null) ...[
                            SizedBox(height: errOffset),
                            _ErrorText(text: _organizationErr!),
                          ],

                          SizedBox(height: baseGap),

                          _AnimatedWrapper(
                            animation: _staggeredAnimations[5],
                            child: _GlassField(
                              height: fieldH,
                              isError: _expiryErr != null,
                              child: GestureDetector(
                                onTap: _selectExpiryDate,
                                child: AbsorbPointer(
                                  child: TextField(
                                    controller: _expiryDateCtrl,
                                    cursorColor: purple,
                                    textAlignVertical: TextAlignVertical.center,
                                    style: TextStyle(
                                      color: (_expiryErr != null) ? errText : enabledText,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                      fontFamily: "Satoshi",
                                    ),
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      hintText: "Expiry Date (MM/DD/YYYY)",
                                      hintStyle: TextStyle(
                                        color: hint,
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.2,
                                        fontFamily: "Satoshi",
                                      ),
                                      contentPadding: padMain(),
                                      suffixIcon: Icon(
                                        Icons.calendar_today_rounded,
                                        color: _expiryErr != null ? errText : purple,
                                        size: 18.sw,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (_expiryErr != null) ...[
                            SizedBox(height: errOffset),
                            _ErrorText(text: _expiryErr!),
                          ],

                          SizedBox(height: 40.sh),

                          _AnimatedWrapper(
                            animation: _staggeredAnimations[6],
                            child: GestureDetector(
                              onTap: _loading ? null : _onRegister,
                              child: Container(
                                width: double.infinity,
                                height: 62.sh,
                                decoration: BoxDecoration(
                                  color: _loading ? hint : btnOrange,
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
                                            child: const CircularProgressIndicator(color: btnText, strokeWidth: 2),
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

                          SizedBox(height: 40.sh),
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



