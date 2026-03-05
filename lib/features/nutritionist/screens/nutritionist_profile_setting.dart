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
import 'package:hidden_pantry_app/features/nutritionist/services/nutritionist_service.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';

class NutritionistProfileSettingScreen extends StatefulWidget {
  const NutritionistProfileSettingScreen({super.key});

  @override
  State<NutritionistProfileSettingScreen> createState() => _NutritionistProfileSettingScreenState();
}

class _NutritionistProfileSettingScreenState extends State<NutritionistProfileSettingScreen> {
  static const double baseW = 393.0;
  static const double baseH = 852.0;

  static const Color bg = Color(0xFFFFF3EB);
  static const Color card = Color(0xFFF9E3D5);
  static const Color text = Color(0xFF462F4D);
  static const Color hintColor = Color(0xFFBFA89A);
  static const Color orange = Color(0xFFF2894F);

  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _orgCtrl = TextEditingController();

  String? _selectedDomain;
  final List<String> _domains = [
    "Clinical Nutrition",
    "Sports Nutrition",
    "Pediatric Nutrition",
    "Weight Management",
    "Plant-Based",
    "Holistic",
    "Diabetes Educator",
    "General Wellness"
  ];

  bool _loading = false;
  bool _notifEnabled = true;
  String? _photoUrl;
  File? _pickedImage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _phoneCtrl.dispose();
    _orgCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('nutritionists')
          .doc(user.uid)
          .get();

      final data = doc.data() ?? {};

      setState(() {
        _nameCtrl.text = data['fullName'] ?? '';
        _bioCtrl.text = data['bio'] ?? '';
        _phoneCtrl.text = data['phoneNumber'] ?? '';
        _orgCtrl.text = data['organizationName'] ?? '';
        _selectedDomain = data['domain'];
        _photoUrl = data['photoUrl'] ?? user.photoURL;
        _notifEnabled = data['notificationsEnabled'] ?? true;
      });
    } catch (e) {
      debugPrint("Error loading profile: $e");
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (x == null) return;
    setState(() => _pickedImage = File(x.path));
  }

  Future<String?> _uploadImage(File file) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final ref = FirebaseStorage.instance
        .ref()
        .child('nutritionist_profiles')
        .child(user.uid);

    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  Future<void> _saveChanges() async {
    setState(() => _loading = true);

    try {
      String? photoUrl = _photoUrl;
      if (_pickedImage != null) {
        photoUrl = await _uploadImage(_pickedImage!);
      }

      await NutritionistService().updateNutritionistProfile(
        fullName: _nameCtrl.text.trim(),
        phoneNumber: _phoneCtrl.text.trim(),
        bio: _bioCtrl.text.trim(),
        organizationName: _orgCtrl.text.trim(),
        domain: _selectedDomain,
        photoUrl: photoUrl,
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('nutritionists')
            .doc(user.uid)
            .update({'notificationsEnabled': _notifEnabled});
      }

      if (mounted) {
        Toaster.show(context, "Profile updated successfully");
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        Toaster.show(context, "Error: $e", isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final s = math.min(w / baseW, h / baseH);
          double x(double v) => v * s;
          double y(double v) => v * s;

          final bottomInset = MediaQuery.of(context).viewInsets.bottom;

          return GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Stack(
              children: [
                Positioned.fill(child: Container(color: bg)),
                const PatternBackground(), // Pattern is Fixed here

                // Scrollable Content
                SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 80), // Space for Fixed Header
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.only(bottom: bottomInset + y(40), top: y(20)),
                          child: Center(
                            child: SizedBox(
                              width: x(baseW),
                              height: y(1020), // Height for all fields
                              child: Stack(
                                children: [
                                  // Profile Picture
                                  Positioned(
                                    left: x(146.5),
                                    top: y(20),
                                    child: Container(
                                      width: x(100),
                                      height: x(100),
                                      decoration: BoxDecoration(
                                        color: card,
                                        shape: BoxShape.circle,
                                        image: _pickedImage != null
                                            ? DecorationImage(image: FileImage(_pickedImage!), fit: BoxFit.cover)
                                            : (_photoUrl != null
                                                ? DecorationImage(image: NetworkImage(_photoUrl!), fit: BoxFit.cover)
                                                : null),
                                      ),
                                      alignment: Alignment.center,
                                      child: _photoUrl == null && _pickedImage == null
                                          ? Icon(Icons.person, size: x(50), color: text)
                                          : null,
                                    ),
                                  ),

                                  // Camera Icon
                                  Positioned(
                                    left: x(221),
                                    top: y(88),
                                    child: GestureDetector(
                                      onTap: _pickImage,
                                      child: Container(
                                        width: x(25),
                                        height: x(25),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF737373),
                                          borderRadius: BorderRadius.circular(x(13)),
                                        ),
                                        alignment: Alignment.center,
                                        child: Icon(Icons.camera_alt_rounded, size: x(14), color: Colors.white),
                                      ),
                                    ),
                                  ),

                                  // Fields
                                  Positioned(left: x(30), top: y(140), child: SizedBox(width: x(332), child: _inputField(controller: _nameCtrl, hintText: "Full Name", icon: Icons.person_outline_rounded, scale: s))),
                                  Positioned(left: x(30), top: y(226), child: SizedBox(width: x(332), child: _inputField(controller: _phoneCtrl, hintText: "Phone Number", icon: Icons.phone_outlined, scale: s, keyboardType: TextInputType.phone))),
                                  Positioned(left: x(30), top: y(312), child: SizedBox(width: x(332), child: _inputField(controller: _orgCtrl, hintText: "Organization Name", icon: Icons.business_rounded, scale: s))),
                                  Positioned(left: x(30), top: y(398), child: SizedBox(width: x(332), child: _domainSelector(scale: s))),
                                  Positioned(left: x(30), top: y(484), child: SizedBox(width: x(332), child: _inputField(controller: _bioCtrl, hintText: "Biography", icon: Icons.description_outlined, scale: s, maxLines: 5, minLines: 1))),
                                  Positioned(left: x(30), top: y(570), child: SizedBox(width: x(332), child: _notificationToggle(scale: s))),
                                  Positioned(left: x(30), top: y(656), child: SizedBox(width: x(332), child: _preferencesCard(scale: s))),

                                  // Save Button
                                  Positioned(
                                    left: x(30),
                                    top: y(786),
                                    child: GestureDetector(
                                      onTap: _loading ? null : _saveChanges,
                                      child: Container(
                                        width: x(332),
                                        height: x(60),
                                        decoration: BoxDecoration(
                                          color: orange,
                                          borderRadius: BorderRadius.circular(x(20)),
                                          boxShadow: [
                                            BoxShadow(color: orange.withValues(alpha:0.3), blurRadius: 15, offset: const Offset(0, 8)),
                                          ],
                                        ),
                                        alignment: Alignment.center,
                                        child: _loading
                                            ? const CircularProgressIndicator(color: Colors.white)
                                            : Text(
                                                'Save Changes',
                                                style: TextStyle(color: Colors.white, fontSize: x(16), fontWeight: FontWeight.bold, fontFamily: 'Satoshi'),
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

                // Fixed Header
                Positioned(
                  left: 30,
                  right: 0,
                  top: 51,
                  height: 50,
                  child: Stack(
                    children: [
                      BackButtonWidget(
                        onPressed: () => Navigator.pop(context),
                        color: text,
                      ),
                      const Center(
                        child: Text(
                          'Profile setting',
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
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required double scale,
    TextInputType keyboardType = TextInputType.text,
    int? maxLines = 1,
    int? minLines,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20 * scale),
      ),
      height: 70 * scale,
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        minLines: minLines,
        style: TextStyle(color: text, fontSize: 12 * scale, fontWeight: FontWeight.w500, fontFamily: 'Satoshi'),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: hintColor, fontSize: 12 * scale, fontWeight: FontWeight.w500, fontFamily: 'Satoshi'),
          prefixIcon: Icon(icon, color: text.withValues(alpha:0.5), size: 18 * scale),
          prefixIconConstraints: BoxConstraints(
            minWidth: 50 * scale,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 22 * scale),
        ),
      ),
    );
  }

  Widget _notificationToggle({required double scale}) {
    return Container(
      width: 332 * scale,
      height: 70 * scale,
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20 * scale),
      ),
      child: Row(
        children: [
          SizedBox(width: 20 * scale),
          Image.asset(
            'assets/icons/notification.png',
            width: 18 * scale,
            height: 18 * scale,
          ),
          SizedBox(width: 12 * scale),
          Text(
            'Notification',
            style: TextStyle(
              color: text,
              fontSize: 12 * scale,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
              fontFamily: 'Satoshi',
            ),
          ),
          const Spacer(),
          _NotifSwitch(
            value: _notifEnabled,
            onChanged: (v) => setState(() => _notifEnabled = v),
            scale: scale,
          ),
          SizedBox(width: 16 * scale),
        ],
      ),
    );
  }

  Widget _preferencesCard({required double scale}) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AllergiesScreen(fromProfile: true)),
        );
      },
      child: Container(
        width: 332 * scale,
        height: 90 * scale,
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(20 * scale),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 25 * scale,
              top: 18 * scale,
              child: Text(
                'Your Preferences',
                style: TextStyle(
                  color: text,
                  fontSize: 20 * scale,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Satoshi',
                ),
              ),
            ),
            Positioned(
              left: 25 * scale,
              top: 48 * scale,
              child: Text(
                'Change your allergies and diet preferences',
                style: TextStyle(
                  color: text,
                  fontSize: 12 * scale,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                  fontFamily: 'Satoshi',
                ),
              ),
            ),
            Positioned(
              right: 20 * scale,
              top: 40 * scale,
              child: Image.asset(
                'assets/icons/next_brown.png',
                width: 18 * scale,
                height: 18 * scale,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _domainSelector({required double scale}) {
    return Container(
      width: 332 * scale,
      height: 70 * scale,
      padding: EdgeInsets.symmetric(horizontal: 20 * scale),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20 * scale),
      ),
      alignment: Alignment.center,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedDomain,
          hint: Text("Select Specialized Domain", style: TextStyle(color: hintColor, fontSize: 12 * scale, fontWeight: FontWeight.w500, fontFamily: 'Satoshi')),
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down_rounded, color: text),
          dropdownColor: card,
          items: _domains.map((d) {
            return DropdownMenuItem(
              value: d,
              child: Text(d, style: TextStyle(color: text, fontSize: 12 * scale, fontWeight: FontWeight.w500, fontFamily: 'Satoshi')),
            );
          }).toList(),
          onChanged: (v) => setState(() => _selectedDomain = v),
        ),
      ),
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
