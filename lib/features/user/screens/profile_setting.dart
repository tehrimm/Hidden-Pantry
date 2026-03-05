import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hidden_pantry_app/features/recipes/screens/allergies.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';


class ProfileSettingScreen extends StatefulWidget {
  const ProfileSettingScreen({super.key});

  @override
  State<ProfileSettingScreen> createState() => _ProfileSettingScreenState();
}

class _ProfileSettingScreenState extends State<ProfileSettingScreen> {
  static const double baseW = 393.0;
  static const double baseH = 852.0;

  static const Color bg = Color(0xFFFFF3EB);
  static const Color card = Color(0xFFF9E3D5);
  static const Color text = Color(0xFF462F4D);
  static const Color hint = Color(0xFFBFA89A);
  static const Color orange = Color(0xFFF2894F);
  static const Color whiteText = Color(0xFFFFF2EA);

  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _notifEnabled = true;
  bool _loading = false;

  String? _photoUrl;
  File? _pickedImage;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    Toaster.show(context, msg, isError: isError);
  }

  Future<void> _loadUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Server first, fallback cache (fast + reliable)
      DocumentSnapshot<Map<String, dynamic>> doc;

      try {
        doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get(const GetOptions(source: Source.cache));
      }

      final data = doc.data() ?? {};

      _nameCtrl.text = (data['fullName'] ?? '').toString();
      _bioCtrl.text = (data['bio'] ?? '').toString();
      _phoneCtrl.text = (data['phone'] ?? '').toString();
      _notifEnabled = (data['notificationsEnabled'] ?? true) == true;
      _photoUrl = (data['photoUrl'] as String?)?.trim() ?? user.photoURL;

      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (x == null) return;
    setState(() => _pickedImage = File(x.path));
  }

Future<String?> _uploadToStorage(File file) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;

  // Must match Storage rule: match /profile_pictures/{uid}
  final ref = FirebaseStorage.instance
      .ref()
      .child('profile_pictures')
      .child(user.uid);

  try {
    final uploadTask = ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    // Optional: progress logs
    uploadTask.snapshotEvents.listen((snap) {
      final progress = (snap.totalBytes == 0)
          ? 0
          : (snap.bytesTransferred / snap.totalBytes * 100);
      debugPrint("Upload progress: ${progress.toStringAsFixed(0)}%");
    });

    // Do not timeout-cancel
    await uploadTask;

    return await ref.getDownloadURL();
  } on FirebaseException catch (e) {
    debugPrint("Storage upload failed: code=${e.code}, message=${e.message}");
    rethrow;
  }
}


  Future<void> _saveChanges() async {
    if (_loading) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _loading = true);

    try {
      String? photoUrl = _photoUrl;

      if (_pickedImage != null) {
        photoUrl = await _uploadToStorage(_pickedImage!);
      }

      final update = <String, dynamic>{
        'fullName': _nameCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'notificationsEnabled': _notifEnabled,
        'photoUrl': photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(update, SetOptions(merge: true))
          .timeout(const Duration(seconds: 15));

      // Also update Auth Profile for consistency
      if (photoUrl != null) {
        await user.updatePhotoURL(photoUrl);
      }
      if (_nameCtrl.text.trim().isNotEmpty) {
        await user.updateDisplayName(_nameCtrl.text.trim());
      }
      await user.reload(); // Refresh auth token/state

      _photoUrl = photoUrl;
      _pickedImage = null;

      if (!mounted) return;
      _snack('Profile updated successfully.');

      // Return to user_profile and signal success if needed
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      if (e.toString().contains('TimeoutException')) {
        _snack('Request timed out. Please check your internet connection.');
      } else if (e.toString().contains('permission-denied')) {
        _snack('Permission denied. Please try again later.');
      } else {
        _snack('Error saving profile.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

void _openPreferences() {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const AllergiesScreen(fromProfile: true)),
  );
}


  void _goBackToProfile() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _goBackToProfile();
      },
      child: Scaffold(
        backgroundColor: bg,

        // Keyboard fix: do not resize whole UI up
        resizeToAvoidBottomInset: false,

        body: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;

            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final s = math.min(w / baseW, h / baseH);

            double x(double v) => v * s;
            double y(double v) => v * s;

            return GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: Stack(
                children: [
                  Positioned.fill(child: Container(color: bg)),
                  const PatternBackground(),

                  // SCROLLABLE CONTENT (Clipped below header)
                  SafeArea(
                    child: Column(
                      children: [
                        const SizedBox(height: 80), // Absolute gap for fixed header
                        Expanded(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.only(bottom: bottomInset + y(40), top: y(20)),
                            child: Center(
                              child: SizedBox(
                                width: x(baseW),
                                height: y(baseH) - 120, 
                                child: Stack(
                                  children: [
                                    // Profile pic
                                    Positioned(
                                      left: x(146),
                                      top: y(20),
                                  child: Container(
                                    width: x(100),
                                    height: x(100),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD9D9D9),
                                      borderRadius: BorderRadius.circular(x(50)),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: _buildProfileImage(),
                                  ),
                                ),

                                // Camera
                                Positioned(
                                  left: x(221),
                                  top: y(88),
                                  child: GestureDetector(
                                    onTap: _pickProfileImage,
                                    child: Container(
                                      width: x(25),
                                      height: x(25),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF737373),
                                        borderRadius: BorderRadius.circular(x(13)),
                                      ),
                                      alignment: Alignment.center,
                                      child: Image.asset(
                                        'assets/icons/camera.png',
                                        width: x(14),
                                        height: x(14),
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),

                                // Name
                                Positioned(
                                  left: x(30),
                                  top: y(128),
                                  child: _InputCard(
                                    width: x(332),
                                    height: y(70),
                                    child: TextField(
                                      controller: _nameCtrl,
                                      style: TextStyle(
                                        color: text,
                                        fontSize: x(12),
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.2,
                                        fontFamily: 'Satoshi',
                                      ),
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        hintText: 'Full Name',
                                        hintStyle: TextStyle(
                                          color: hint,
                                          fontSize: x(12),
                                          fontWeight: FontWeight.w500,
                                          fontFamily: 'Satoshi',
                                        ),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: x(24),
                                          vertical: y(22),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Bio
                                Positioned(
                                  left: x(30),
                                  top: y(214),
                                  child: _InputCard(
                                    width: x(332),
                                    height: y(70),
                                    child: TextField(
                                      controller: _bioCtrl,
                                      style: TextStyle(
                                        color: text,
                                        fontSize: x(12),
                                        fontWeight: FontWeight.w500,
                                        fontFamily: 'Satoshi',
                                      ),
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        hintText: 'Bio',
                                        hintStyle: TextStyle(
                                          color: hint,
                                          fontSize: x(12),
                                          fontWeight: FontWeight.w500,
                                          fontFamily: 'Satoshi',
                                        ),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: x(24),
                                          vertical: y(22),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Phone
                                Positioned(
                                  left: x(30),
                                  top: y(300),
                                  child: _InputCard(
                                    width: x(332),
                                    height: y(70),
                                    child: TextField(
                                      controller: _phoneCtrl,
                                      keyboardType: TextInputType.phone,
                                      style: TextStyle(
                                        color: text,
                                        fontSize: x(12),
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.2,
                                        fontFamily: 'Satoshi',
                                      ),
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        hintText: 'Phone number',
                                        hintStyle: TextStyle(
                                          color: hint,
                                          fontSize: x(12),
                                          fontWeight: FontWeight.w500,
                                          fontFamily: 'Satoshi',
                                        ),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: x(24),
                                          vertical: y(22),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Notification toggle
                                Positioned(
                                  left: x(30),
                                  top: y(386),
                                  child: _InputCard(
                                    width: x(332),
                                    height: y(70),
                                    child: Row(
                                      children: [
                                        SizedBox(width: x(20)),
                                        Image.asset(
                                          'assets/icons/notification.png',
                                          width: x(18),
                                          height: x(18),
                                        ),
                                        SizedBox(width: x(12)),
                                        Text(
                                          'Notification',
                                          style: TextStyle(
                                            color: text,
                                            fontSize: x(12),
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: 0.2,
                                            fontFamily: 'Satoshi',
                                          ),
                                        ),
                                        const Spacer(),
                                        _NotifSwitch(
                                          value: _notifEnabled,
                                          onChanged: (v) => setState(() => _notifEnabled = v),
                                          scale: s,
                                        ),
                                        SizedBox(width: x(16)),
                                      ],
                                    ),
                                  ),
                                ),

                                // Preferences card
                                Positioned(
                                  left: x(30),
                                  top: y(472),
                                  child: GestureDetector(
                                    onTap: _openPreferences,
                                    child: Container(
                                      width: x(332),
                                      height: y(90),
                                      decoration: BoxDecoration(
                                        color: card,
                                        borderRadius: BorderRadius.circular(x(20)),
                                      ),
                                      child: Stack(
                                        children: [
                                          Positioned(
                                            left: x(25),
                                            top: y(18),
                                            child: Text(
                                              'Your Preferences',
                                              style: TextStyle(
                                                color: text,
                                                fontSize: x(20),
                                                fontWeight: FontWeight.w700,
                                                fontFamily: 'Satoshi',
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            left: x(25),
                                            top: y(48),
                                            child: Text(
                                              'Change your allergies and diet preferences',
                                              style: TextStyle(
                                                color: text,
                                                fontSize: x(12),
                                                fontWeight: FontWeight.w500,
                                                letterSpacing: 0.2,
                                                fontFamily: 'Satoshi',
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            right: x(20),
                                            top: y(40),
                                            child: Image.asset(
                                              'assets/icons/next_brown.png',
                                              width: x(18),
                                              height: x(18),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                // Save button
                                Positioned(
                                  left: x(30),
                                  top: y(582),
                                  child: GestureDetector(
                                    onTap: _loading ? null : _saveChanges,
                                    child: Container(
                                      width: x(332),
                                      height: y(62),
                                      decoration: BoxDecoration(
                                        color: orange,
                                        borderRadius: BorderRadius.circular(x(20)),
                                      ),
                                      alignment: Alignment.center,
                                      child: _loading
                                          ? SizedBox(
                                              width: x(22),
                                              height: x(22),
                                              child: const CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Text(
                                              'Save Changes',
                                              style: TextStyle(
                                                color: whiteText,
                                                fontSize: x(15),
                                                fontWeight: FontWeight.w700,
                                                fontFamily: 'Satoshi',
                                              ),
                                            ),
                                    ),
                                  ),
                                ),

                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // FIXED HEADER
                  Positioned(
                    left: 30,
                    right: 0,
                    top: 51,
                    height: 50,
                    child: Stack(
                      children: [
                        BackButtonWidget(
                          onPressed: _goBackToProfile,
                          color: text,
                        ),
                        Center(
                          child: Text(
                            'Your profile',
                            style: TextStyle(
                              color: text,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Satoshi',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileImage() {
    if (_pickedImage != null) {
      return Image.file(_pickedImage!, fit: BoxFit.cover);
    }
    if (_photoUrl != null && _photoUrl!.trim().isNotEmpty) {
      return Image.network(
        _photoUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholderImage(),
      );
    }
    return _placeholderImage();
  }

  Widget _placeholderImage() {
    return Center(
      child: Image.asset(
        'assets/Logos/profile_placeholder.png',
        width: 22,
        height: 22,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  final double width;
  final double height;
  final Widget child;

  const _InputCard({
    required this.width,
    required this.height,
    required this.child,
  });

  static const Color card = Color(0xFFF9E3D5);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}

class _NotifSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final double scale;

  const _NotifSwitch({
    required this.value,
    required this.onChanged,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    // exact sizes requested
    final trackW = 25.0 * scale;
    final trackH = 10.0 * scale;
    final knobSize = 15.0 * scale;

    final trackColor = value ? const Color(0xFFDFBFE5) : const Color(0xFFE5CCBF);
    final knobColor = value ? const Color(0xFF462F4D) : const Color(0xFF74503C);

    return GestureDetector(
      onTap: () => onChanged(!value),
      child: SizedBox(
        width: trackW,
        height: math.max(trackH, knobSize),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: trackW,
                height: trackH,
                decoration: BoxDecoration(
                  color: trackColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            AnimatedAlign(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: knobSize,
                height: knobSize,
                decoration: BoxDecoration(
                  color: knobColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

