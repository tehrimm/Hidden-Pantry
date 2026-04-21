
import 'dart:io';
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

class _SignupNutritionistStep2State extends State<SignupNutritionistStep2> {
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

  // Base size
  // Removed legacy base constants


  @override
  void dispose() {
    _licenseCtrl.dispose();
    _organizationCtrl.dispose();
    _expiryDateCtrl.dispose();
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
      // Basic date validation (MM/DD/YYYY or DD/MM/YYYY)
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

    if (!ok) {
      if (_certErr != null) {
        _snack("Please upload your certificate");
      } else if (_licenseErr != null) {
        _snack("License Error: $_licenseErr");
      } else if (_organizationErr != null) {
        _snack("Organization Error: $_organizationErr");
      } else if (_expiryErr != null) {
        _snack("Expiry Date Error: $_expiryErr");
      }
    }
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
    debugPrint("_onRegister called");

    if (_loading) {
      debugPrint("Already loading, ignoring tap");
      return;
    }

    if (!_validate()) {
      debugPrint("Validation failed");
      return;
    }

    final license = _licenseCtrl.text.trim();
    final organization = _organizationCtrl.text.trim();
    final expiryDate = _expiryDateCtrl.text.trim();

    _setLoading(true);

    try {
      User? user = FirebaseAuth.instance.currentUser;

      // 1) Auth creation (if not social login)
      if (user == null) {
        if (widget.password == null) throw Exception("Missing authentication context");
        debugPrint("Creating user in Firebase Auth...");
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: widget.email,
          password: widget.password!,
        );
        user = cred.user;
      }

      if (user == null) throw Exception("Authentication failed");
      debugPrint("Auth success: ${user.uid}");

      // 2) Sequential but optimized: Upload -> Create Profile
      debugPrint("Uploading certificate...");
      final certificateUrl = await _nutritionistService.uploadCertificate(
        _certificateFile!,
        user.uid,
      );
      
      debugPrint("Saving nutritionist profile...");
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

      // 3) Success UI - Ensure no build phase conflict
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

        // 4) Final Navigation
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const NutritionistPendingScreen()),
        );
      });

    } on FirebaseAuthException catch (e) {
      debugPrint("FirebaseAuthException: ${e.code} / ${e.message}");
      if (!mounted) return;
      String errorMsg = "Signup failed";
      if (e.code == "email-already-in-use") errorMsg = "Email already in use";
      else if (e.code == "weak-password") errorMsg = "Password is too weak";
      else if (e.code == "invalid-email") errorMsg = "Invalid email";
      _snack(errorMsg);
    } catch (e) {
      debugPrint("Generic Error: $e");
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
            colorScheme: ColorScheme.light(
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

  // ======================= UI =======================
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
                  const PatternBackground(),

                  Column(
                    children: [
                      // Fixed Top row (Back + Login)
                      Padding(
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

                      // Main scroll content
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

                          // Title
                          SizedBox(
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

                          SizedBox(height: 46.sh),

                          // ================= UPLOAD CERTIFICATE =================
                          SizedBox(
                            width: 332.sw,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: _pickCertificate,
                                  child: Container(
                                    width: 332.sw,
                                    height: 70.sh,
                                    decoration: BoxDecoration(
                                      color: bg,
                                      border: Border.all(
                                        color: _certErr != null ? errText : btnOrange,
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(20.sw),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.upload_file,
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
                                if (_certErr != null) ...[
                                  SizedBox(height: 4.sh),
                                  Padding(
                                    padding: EdgeInsets.only(left: 12.sw),
                                    child: Text(
                                      _certErr!,
                                      style: TextStyle(
                                        color: errText,
                                        fontSize: 10.sp,
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

                          // ================= LICENSE NUMBER =================
                          SizedBox(
                            width: 332.sw,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldBox(
                                  width: 332.sw,
                                  height: fieldH,
                                  isError: _licenseErr != null,
                                  child: TextField(
                                    controller: _licenseCtrl,
                                    onChanged: (_) => setState(() {}),
                                    cursorColor: purple,
                                    textAlignVertical: TextAlignVertical.center,
                                    style: TextStyle(
                                      color: (_licenseErr != null)
                                          ? errText
                                          : (_licenseCtrl.text.trim().isEmpty
                                              ? hint
                                              : enabledText),
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
                                      isDense: false,
                                      contentPadding: padMain(),
                                    ),
                                  ),
                                ),
                                if (_licenseErr != null) ...[
                                  SizedBox(height: errOffset),
                                  Padding(
                                    padding: EdgeInsets.only(left: 12.sw),
                                    child: Text(
                                      _licenseErr!,
                                      style: TextStyle(
                                        color: errText,
                                        fontSize: 10.sp,
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

                          // ================= ORGANIZATION NAME =================
                          SizedBox(
                            width: 332.sw,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldBox(
                                  width: 332.sw,
                                  height: fieldH,
                                  isError: _organizationErr != null,
                                  child: TextField(
                                    controller: _organizationCtrl,
                                    onChanged: (_) => setState(() {}),
                                    cursorColor: purple,
                                    textAlignVertical: TextAlignVertical.center,
                                    style: TextStyle(
                                      color: (_organizationErr != null)
                                          ? errText
                                          : (_organizationCtrl.text.trim().isEmpty
                                              ? hint
                                              : enabledText),
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
                                      isDense: false,
                                      contentPadding: padMain(),
                                    ),
                                  ),
                                ),
                                if (_organizationErr != null) ...[
                                  SizedBox(height: errOffset),
                                  Padding(
                                    padding: EdgeInsets.only(left: 12.sw),
                                    child: Text(
                                      _organizationErr!,
                                      style: TextStyle(
                                        color: errText,
                                        fontSize: 10.sp,
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

                          // ================= EXPIRY DATE =================
                          SizedBox(
                            width: 332.sw,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldBox(
                                  width: 332.sw,
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
                                            color: (_expiryErr != null)
                                                ? errText
                                            : (_expiryDateCtrl.text.trim().isEmpty
                                                    ? hint
                                                    : enabledText),
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
                                          isDense: false,
                                          contentPadding: padMain(),
                                          suffixIcon: Icon(
                                            Icons.calendar_today,
                                            color: _expiryErr != null ? errText : purple,
                                            size: 18.sw,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (_expiryErr != null) ...[
                                  SizedBox(height: errOffset),
                                  Padding(
                                    padding: EdgeInsets.only(left: 12.sw),
                                    child: Text(
                                      _expiryErr!,
                                      style: TextStyle(
                                        color: errText,
                                        fontSize: 10.sp,
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

                          SizedBox(height: 30.sh),

                          // Register button
                          GestureDetector(
                            onTap: _loading ? null : _onRegister,
                            child: Container(
                              width: 332.sw,
                              height: 62.sh,
                              decoration: BoxDecoration(
                                color: _loading ? hint : btnOrange,
                                borderRadius: BorderRadius.circular(20.sw),
                              ),
                              alignment: Alignment.center,
                              child: _loading
                                  ? SizedBox(
                                      width: 24.sw,
                                      height: 24.sw,
                                      child: CircularProgressIndicator(
                                        color: btnText,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      "Register",
                                      style: TextStyle(
                                        color: btnText,
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: "Satoshi",
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



