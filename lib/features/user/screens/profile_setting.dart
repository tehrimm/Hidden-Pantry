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
import 'package:hidden_pantry_app/features/recipes/services/recipe_service.dart';
import 'package:hidden_pantry_app/features/user/screens/blocked_authors.dart';


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
  bool _voiceEnabled = true;
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
      _voiceEnabled = (data['voiceEnabled'] ?? true) == true;
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
        'voiceEnabled': _voiceEnabled,
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
      
      // 🔄 SYNC: Update author info on all recipes
      try {
        await RecipeService().syncAuthorName(
          user.uid, 
          _nameCtrl.text.trim(), 
          photoUrl
        );
      } catch (syncErr) {
        print("[ProfileSetting] Background sync failed: $syncErr");
      }

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

void _openBlockedAuthors() {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const BlockedAuthorsScreen()),
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
                  const _UserSettingBackgroundPattern(),

                  const PatternBackground(),

                  // Decorative corner shapes
                  Positioned(
                    top: -30.sh, right: -30.sw,
                    child: Container(width: 120.sw, height: 120.sw,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: orange.withValues(alpha: 0.06))),
                  ),
                  Positioned(
                    bottom: -40.sh, left: -40.sw,
                    child: Container(width: 160.sw, height: 160.sw,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: text.withValues(alpha: 0.04))),
                  ),
                  Positioned(
                    top: 200.sh, left: 16.sw,
                    child: Container(width: 10.sw, height: 10.sw,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: orange.withValues(alpha: 0.15))),
                  ),
                  Positioned(
                    top: 320.sh, right: 20.sw,
                    child: Transform.rotate(angle: math.pi / 4,
                      child: Container(width: 16.sw, height: 16.sw,
                        decoration: BoxDecoration(color: text.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(3.sw)))),
                  ),

                  // SCROLLABLE CONTENT
                  SafeArea(
                    child: Column(
                      children: [
                        SizedBox(height: 80.sh), // Gap for fixed header
                        Expanded(
                          child: ListView(
                            padding: EdgeInsets.fromLTRB(30.sw, 20.sh, 30.sw, bottomInset + 40.sh),
                            children: [
                              // Profile pic
                              _FadeSlideEntry(
                                delayMs: 100,
                                child: Center(
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: 100.sw,
                                        height: 100.sw,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFD9D9D9),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 3),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.1),
                                              blurRadius: 15,
                                              offset: const Offset(0, 5),
                                            ),
                                          ],
                                        ),
                                        child: ClipOval(
                                          child: SizedBox(
                                            width: 100.sw,
                                            height: 100.sw,
                                            child: _buildProfileImage(),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: GestureDetector(
                                          onTap: _pickProfileImage,
                                          child: Container(
                                            width: 32.sw,
                                            height: 32.sw,
                                            decoration: BoxDecoration(
                                              color: orange,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white, width: 2),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: orange.withValues(alpha: 0.3),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            alignment: Alignment.center,
                                            child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16.sw),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: 32.sh),

                              // Name
                              _FadeSlideEntry(
                                delayMs: 200,
                                child: _InputCard(
                                  child: TextField(
                                    controller: _nameCtrl,
                                    style: TextStyle(
                                      color: text,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Satoshi',
                                    ),
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      hintText: 'Full Name',
                                      hintStyle: TextStyle(
                                        color: hint,
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w500,
                                        fontFamily: 'Satoshi',
                                      ),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 20.sw, vertical: 18.sh),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 16.sh),

                              // Bio
                              _FadeSlideEntry(
                                delayMs: 300,
                                child: _InputCard(
                                  child: TextField(
                                    controller: _bioCtrl,
                                    style: TextStyle(
                                      color: text,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Satoshi',
                                    ),
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      hintText: 'Bio',
                                      hintStyle: TextStyle(
                                        color: hint,
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w500,
                                        fontFamily: 'Satoshi',
                                      ),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 20.sw, vertical: 18.sh),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 16.sh),

                              // Phone
                              _FadeSlideEntry(
                                delayMs: 400,
                                child: _InputCard(
                                  child: TextField(
                                    controller: _phoneCtrl,
                                    keyboardType: TextInputType.phone,
                                    style: TextStyle(
                                      color: text,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Satoshi',
                                    ),
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      hintText: 'Phone number',
                                      hintStyle: TextStyle(
                                        color: hint,
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w500,
                                        fontFamily: 'Satoshi',
                                      ),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 20.sw, vertical: 18.sh),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 16.sh),

                              // Notification toggle
                              _FadeSlideEntry(
                                delayMs: 500,
                                child: _InputCard(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 20.sw, vertical: 18.sh),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 36.sw,
                                          height: 36.sw,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.6),
                                            borderRadius: BorderRadius.circular(10.sw),
                                          ),
                                          child: Center(
                                            child: Image.asset(
                                              'assets/icons/notification.png',
                                              width: 18.sw,
                                              height: 18.sw,
                                              color: text,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 16.sw),
                                        Expanded(
                                          child: Text(
                                            'Notifications',
                                            style: TextStyle(
                                              color: text,
                                              fontSize: 15.sp,
                                              fontWeight: FontWeight.w600,
                                              fontFamily: 'Satoshi',
                                            ),
                                          ),
                                        ),
                                        _NotifSwitch(
                                          value: _notifEnabled,
                                          onChanged: (v) => setState(() => _notifEnabled = v),
                                          text: text,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 16.sh),

                              // Voice Mode toggle
                              _FadeSlideEntry(
                                delayMs: 550,
                                child: _InputCard(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 20.sw, vertical: 18.sh),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 36.sw,
                                          height: 36.sw,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.6),
                                            borderRadius: BorderRadius.circular(10.sw),
                                          ),
                                          child: Center(
                                            child: Icon(Icons.mic_rounded, color: text, size: 20.sw),
                                          ),
                                        ),
                                        SizedBox(width: 16.sw),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Voice-Controlled Cooking',
                                                style: TextStyle(
                                                  color: text,
                                                  fontSize: 15.sp,
                                                  fontWeight: FontWeight.w600,
                                                  fontFamily: 'Satoshi',
                                                ),
                                              ),
                                              Text(
                                                'Hands-free step navigation',
                                                style: TextStyle(
                                                  color: hint,
                                                  fontSize: 11.sp,
                                                  fontWeight: FontWeight.w500,
                                                  fontFamily: 'Satoshi',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        _NotifSwitch(
                                          value: _voiceEnabled,
                                          onChanged: (v) => setState(() => _voiceEnabled = v),
                                          text: text,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 16.sh),

                              // Preferences card
                              _FadeSlideEntry(
                                delayMs: 600,
                                child: GestureDetector(
                                  onTap: _openPreferences,
                                  child: _InputCard(
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 20.sw, vertical: 20.sh),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Your Preferences',
                                                  style: TextStyle(
                                                    color: text,
                                                    fontSize: 18.sp,
                                                    fontWeight: FontWeight.w700,
                                                    fontFamily: 'Satoshi',
                                                  ),
                                                ),
                                                SizedBox(height: 4.sh),
                                                Text(
                                                  'Change your allergies and diet preferences',
                                                  style: TextStyle(
                                                    color: hint,
                                                    fontSize: 12.sp,
                                                    fontWeight: FontWeight.w500,
                                                    fontFamily: 'Satoshi',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(Icons.arrow_forward_ios_rounded, color: text.withValues(alpha: 0.5), size: 16.sw),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 16.sh),

                              // Blocked Authors card
                              _FadeSlideEntry(
                                delayMs: 650,
                                child: GestureDetector(
                                  onTap: _openBlockedAuthors,
                                  child: _InputCard(
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 20.sw, vertical: 20.sh),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Blocked Authors',
                                                  style: TextStyle(
                                                    color: text,
                                                    fontSize: 18.sp,
                                                    fontWeight: FontWeight.w700,
                                                    fontFamily: 'Satoshi',
                                                  ),
                                                ),
                                                SizedBox(height: 4.sh),
                                                Text(
                                                  'Manage people you\'ve blocked',
                                                  style: TextStyle(
                                                    color: hint,
                                                    fontSize: 12.sp,
                                                    fontWeight: FontWeight.w500,
                                                    fontFamily: 'Satoshi',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(Icons.arrow_forward_ios_rounded, color: text.withValues(alpha: 0.5), size: 16.sw),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 32.sh),

                              // Save button
                              _FadeSlideEntry(
                                delayMs: 700,
                                child: GestureDetector(
                                  onTap: _loading ? null : _saveChanges,
                                  child: Container(
                                    height: 62.sh,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [orange, Color(0xFFFFA06A)],
                                      ),
                                      borderRadius: BorderRadius.circular(20.sw),
                                      boxShadow: [
                                        BoxShadow(
                                          color: orange.withValues(alpha: 0.3),
                                          blurRadius: 12,
                                          offset: const Offset(0, 6),
                                        )
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: _loading
                                        ? SizedBox(
                                            width: 22.sw,
                                            height: 22.sw,
                                            child: CircularProgressIndicator(color: orange),
                                          )
                                        : Text(
                                            'Save Changes',
                                            style: TextStyle(
                                              color: whiteText,
                                              fontSize: 16.sp,
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
                      ],
                    ),
                  ),

                  // Fixed Header
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
        'assets/logos/profile_placeholder.png',
        width: 32.sw,
        height: 32.sw,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  final Widget child;

  const _InputCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(22.sw),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: child,
    );
  }
}

class _NotifSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color text;

  const _NotifSwitch({
    required this.value,
    required this.onChanged,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final trackW = 44.sw;
    final trackH = 24.sh;
    final knobSize = 20.sw;

    final trackColor = value ? text.withValues(alpha: 0.3) : text.withValues(alpha: 0.15);
    final knobColor = text;

    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: trackW,
        height: trackH,
        decoration: BoxDecoration(
          color: trackColor,
          borderRadius: BorderRadius.circular(999),
        ),
        padding: EdgeInsets.all(2.sw),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: knobSize,
            height: knobSize,
            decoration: BoxDecoration(
              color: knobColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FadeSlideEntry extends StatefulWidget {
  final Widget child;
  final int delayMs;
  const _FadeSlideEntry({required this.child, this.delayMs = 0});

  @override
  State<_FadeSlideEntry> createState() => _FadeSlideEntryState();
}

class _FadeSlideEntryState extends State<_FadeSlideEntry> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

class _UserSettingBackgroundPattern extends StatelessWidget {
  const _UserSettingBackgroundPattern();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -100.sh,
            right: -100.sw,
            child: _UserSettingFloatingOrb(
              color: const Color(0xFFFFE0D3).withValues(alpha: 0.5),
              size: 400,
              duration: const Duration(seconds: 15),
            ),
          ),
          Positioned(
            bottom: 100.sh,
            left: -150.sw,
            child: _UserSettingFloatingOrb(
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

class _UserSettingFloatingOrb extends StatefulWidget {
  final Color color;
  final double size;
  final Duration duration;

  const _UserSettingFloatingOrb({required this.color, required this.size, required this.duration});

  @override
  State<_UserSettingFloatingOrb> createState() => _UserSettingFloatingOrbState();
}

class _UserSettingFloatingOrbState extends State<_UserSettingFloatingOrb> with SingleTickerProviderStateMixin {
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

