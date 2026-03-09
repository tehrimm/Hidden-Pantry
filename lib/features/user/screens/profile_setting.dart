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
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';



class ProfileSettingScreen extends StatefulWidget {
  const ProfileSettingScreen({super.key});

  @override
  State<ProfileSettingScreen> createState() => _ProfileSettingScreenState();
}

class _ProfileSettingScreenState extends State<ProfileSettingScreen> {
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
        body: Builder(
          builder: (context) {
            ResponsiveUtils.init(context);
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final topPad = MediaQuery.of(context).padding.top;
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
                        SizedBox(height: 96.sh), // Absolute gap for fixed header
                        Expanded(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.only(bottom: bottomInset + 40.sh),
                            child: Center(
                              child: Container(
                                width: double.infinity,
                                height: 852.sh,
                                child: Stack(
                                  children: [
                                    // Profile pic
                                    Positioned(
                                      left: 146.sw,
                                      top: 20.sh,
                                  child: Container(
                                    width: 100.sw,
                                    height: 100.sw,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD9D9D9),
                                      borderRadius: BorderRadius.circular(50.sw),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: _buildProfileImage(),
                                  ),
                                ),

                                // Camera
                                Positioned(
                                  left: 221.sw,
                                  top: 88.sh,
                                  child: GestureDetector(
                                    onTap: _pickProfileImage,
                                    child: Container(
                                      width: 25.sw,
                                      height: 25.sw,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF737373),
                                        borderRadius: BorderRadius.circular(13.sw),
                                      ),
                                      alignment: Alignment.center,
                                      child: Image.asset(
                                        'assets/icons/camera.png',
                                        width: 14.sw,
                                        height: 14.sw,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),

                                // Name
                                Positioned(
                                  left: 30.sw,
                                  top: 128.sh,
                                  child: _InputCard(
                                    width: 332.sw,
                                    height: 70.sh,
                                    child: TextField(
                                      controller: _nameCtrl,
                                      style: TextStyle(
                                        color: text,
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.2,
                                        fontFamily: 'Satoshi',
                                      ),
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        hintText: 'Full Name',
                                        hintStyle: TextStyle(
                                          color: hint,
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w500,
                                          fontFamily: 'Satoshi',
                                        ),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 24.sw,
                                          vertical: 22.sh,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Bio
                                Positioned(
                                  left: 30.sw,
                                  top: 214.sh,
                                  child: _InputCard(
                                    width: 332.sw,
                                    height: 70.sh,
                                    child: TextField(
                                      controller: _bioCtrl,
                                      style: TextStyle(
                                        color: text,
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w500,
                                        fontFamily: 'Satoshi',
                                      ),
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        hintText: 'Bio',
                                        hintStyle: TextStyle(
                                          color: hint,
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w500,
                                          fontFamily: 'Satoshi',
                                        ),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 24.sw,
                                          vertical: 22.sh,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Phone
                                Positioned(
                                  left: 30.sw,
                                  top: 300.sh,
                                  child: _InputCard(
                                    width: 332.sw,
                                    height: 70.sh,
                                    child: TextField(
                                      controller: _phoneCtrl,
                                      keyboardType: TextInputType.phone,
                                      style: TextStyle(
                                        color: text,
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.2,
                                        fontFamily: 'Satoshi',
                                      ),
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        hintText: 'Phone number',
                                        hintStyle: TextStyle(
                                          color: hint,
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w500,
                                          fontFamily: 'Satoshi',
                                        ),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 24.sw,
                                          vertical: 22.sh,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Notification toggle
                                Positioned(
                                  left: 30.sw,
                                  top: 386.sh,
                                  child: _InputCard(
                                    width: 332.sw,
                                    height: 70.sh,
                                    child: Row(
                                      children: [
                                        SizedBox(width: 20.sw),
                                        Image.asset(
                                          'assets/icons/notification.png',
                                          width: 18.sw,
                                          height: 18.sw,
                                        ),
                                        SizedBox(width: 12.sw),
                                        Text(
                                          'Notification',
                                          style: TextStyle(
                                            color: text,
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: 0.2,
                                            fontFamily: 'Satoshi',
                                          ),
                                        ),
                                        const Spacer(),
                                        _NotifSwitch(
                                          value: _notifEnabled,
                                          onChanged: (v) => setState(() => _notifEnabled = v),
                                        ),
                                        SizedBox(width: 16.sw),
                                      ],
                                    ),
                                  ),
                                ),

                                // Preferences card
                                Positioned(
                                  left: 30.sw,
                                  top: 472.sh,
                                  child: GestureDetector(
                                    onTap: _openPreferences,
                                    child: Container(
                                      width: 332.sw,
                                      height: 90.sh,
                                      decoration: BoxDecoration(
                                        color: card,
                                        borderRadius: BorderRadius.circular(20.sw),
                                      ),
                                      child: Stack(
                                        children: [
                                          Positioned(
                                            left: 25.sw,
                                            top: 18.sh,
                                            child: Text(
                                              'Your Preferences',
                                              style: TextStyle(
                                                color: text,
                                                fontSize: 20.sp,
                                                fontWeight: FontWeight.w700,
                                                fontFamily: 'Satoshi',
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            left: 25.sw,
                                            top: 48.sh,
                                            child: Text(
                                              'Change your allergies and diet preferences',
                                              style: TextStyle(
                                                color: text,
                                                fontSize: 12.sp,
                                                fontWeight: FontWeight.w500,
                                                letterSpacing: 0.2,
                                                fontFamily: 'Satoshi',
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            right: 20.sw,
                                            top: 40.sh,
                                            child: Image.asset(
                                              'assets/icons/next_brown.png',
                                              width: 18.sw,
                                              height: 18.sw,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                // Save button
                                Positioned(
                                  left: 30.sw,
                                  top: 582.sh,
                                  child: GestureDetector(
                                    onTap: _loading ? null : _saveChanges,
                                    child: Container(
                                      width: 332.sw,
                                      height: 62.sh,
                                      decoration: BoxDecoration(
                                        color: orange,
                                        borderRadius: BorderRadius.circular(20.sw),
                                      ),
                                      alignment: Alignment.center,
                                      child: _loading
                                          ? SizedBox(
                                              width: 22.sw,
                                              height: 22.sw,
                                              child: const CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Text(
                                              'Save Changes',
                                              style: TextStyle(
                                                color: whiteText,
                                                fontSize: 15.sp,
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

                  Positioned(
                    left: 30.sw,
                    right: 0,
                    top: topPad + 36.sh,
                    height: 50.sh,
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
                              fontSize: 24.sp,
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
        width: 22.sw,
        height: 22.sw,
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
        borderRadius: BorderRadius.circular(20.sw),
      ),
      child: child,
    );
  }
}

class _NotifSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NotifSwitch({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // exact sizes requested
    final trackW = 25.sw;
    final trackH = 10.sh;
    final knobSize = 15.sw;

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

