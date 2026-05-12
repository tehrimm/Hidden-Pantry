import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'upload_recipe_step2.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';


class UploadRecipeStep1 extends StatefulWidget {
  final Recipe? editingRecipe;
  const UploadRecipeStep1({super.key, this.editingRecipe});

  @override
  State<UploadRecipeStep1> createState() => _UploadRecipeStep1State();
}

class _UploadRecipeStep1State extends State<UploadRecipeStep1> {
  late final TextEditingController _titleController;
  File? _image;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.editingRecipe?.name ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _cropImage(String path) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: path,
      aspectRatio: CropAspectRatio(ratioX: 1, ratioY: 1), // Square for recipes
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Adjust Image',
          toolbarColor: purple,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          activeControlsWidgetColor: orange,
          backgroundColor: const Color(0xFFFFF3EB),
        ),
        IOSUiSettings(
          title: 'Adjust Image',
          aspectRatioLockEnabled: true,
          resetButtonHidden: false,
          aspectRatioPickerButtonHidden: true,
        ),
      ],
    );

    if (croppedFile != null) {
      setState(() {
        _image = File(croppedFile.path);
      });
    }
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.all(24.sw),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3EB).withValues(alpha: 0.8),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30.sw)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40.sw, height: 4.sh, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2))),
              SizedBox(height: 24.sh),
              _sourceTile(Icons.photo_library_rounded, "Gallery", () async {
                final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                if (image != null) {
                  final int bytes = await image.length();
                  if (bytes > 5 * 1024 * 1024) {
                    if (mounted) Toaster.show(context, 'Image too large (Max 5MB)', isError: true);
                    return;
                  }
                  await _cropImage(image.path);
                }
              }),
              SizedBox(height: 12.sh),
              _sourceTile(Icons.camera_alt_rounded, "Camera", () async {
                final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
                if (photo != null) {
                  final int bytes = await photo.length();
                  if (bytes > 5 * 1024 * 1024) {
                    if (mounted) Toaster.show(context, 'Image too large (Max 5MB)', isError: true);
                    return;
                  }
                  await _cropImage(photo.path);
                }
              }),
              SizedBox(height: 24.sh),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sourceTile(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Container(
        padding: EdgeInsets.all(16.sw),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(15.sw),
          border: Border.all(color: Colors.white, width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: purple),
            SizedBox(width: 16.sw),
            Text(label, style: TextStyle(fontFamily: 'Satoshi', fontWeight: FontWeight.bold, fontSize: 16.sp, color: purple)),
          ],
        ),
      ),
    );
  }

  final Color purple = const Color(0xFF462F4D);
  final Color orange = const Color(0xFFEF8A54);
  final Color cardBg = const Color(0xFFF9E3D5);

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3EB),
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Background Patterns
          PatternBackground(),

          Column(
            children: [
              SizedBox(height: 50.sh),
              // Fixed Header area
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 29.sw),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    BackButtonWidget(color: purple),
                    Text(
                      widget.editingRecipe != null ? 'Edit Recipe' : 'Add Recipe',
                      style: TextStyle(
                        color: purple,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Satoshi',
                      ),
                    ),
                    Container(
                      width: 69.sw,
                      height: 42.sh,
                      decoration: BoxDecoration(
                        color: purple,
                        borderRadius: BorderRadius.circular(10.sw),
                      ),
                      child: Center(
                        child: Text(
                          '1/5',
                          style: TextStyle(
                            color: Color(0xFFFFF2EA),
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Satoshi',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable Content
              Expanded(
                child: ListView(
                  padding: EdgeInsets.only(top: 20.sh, bottom: 120.sh),
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 29.sw),
                      child: _StaggeredFadeIn(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Title',
                              style: TextStyle(
                                color: Color(0xFF462F4D),
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Satoshi',
                              ),
                            ),
                            SizedBox(height: 32.sh),
                            Container(
                              height: 70.sh,
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(20.sw),
                              ),
                              padding: EdgeInsets.symmetric(horizontal: 25.sw),
                              alignment: Alignment.centerLeft,
                              child: TextField(
                                controller: _titleController,
                                style: TextStyle(
                                  color: purple,
                                  fontSize: 15.sp,
                                  fontFamily: 'Satoshi',
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Enter recipe title',
                                  border: InputBorder.none,
                                  hintStyle: TextStyle(color: Color(0x66462F4D), fontSize: 15.sp),
                                ),
                              ),
                            ),
                            SizedBox(height: 23.sh),
                            GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                height: 220.sh,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(23.sw),
                                ),
                                child: _image != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(23.sw),
                                        child: Image.file(_image!, fit: BoxFit.cover),
                                      )
                                    : (widget.editingRecipe?.imageUrl != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(23.sw),
                                            child: Image.network(
                                              widget.editingRecipe!.imageUrl!, 
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => Center(
                                                child: Icon(Icons.broken_image_rounded, color: purple.withValues(alpha: 0.2), size: 48.sw),
                                              ),
                                            ),
                                          )
                                        : FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.add_photo_alternate_rounded, size: 48.sw, color: purple.withValues(alpha: 0.4)),
                                                SizedBox(height: 12.sh),
                                                Text('Add Recipe Photo', style: TextStyle(color: purple.withValues(alpha: 0.4), fontSize: 16.sp, fontWeight: FontWeight.w900, fontFamily: 'Satoshi')),
                                                Text('High quality photos get more likes', style: TextStyle(color: purple.withValues(alpha: 0.25), fontSize: 12.sp, fontFamily: 'Satoshi')),
                                              ],
                                            ),
                                          )),
                              ),
                            ),
                            SizedBox(height: 5.sh),
                            Text(
                              '*Maximum size 5MB (1080x1080 recommended)',
                              style: TextStyle(
                                color: purple.withValues(alpha: 0.6),
                                fontSize: 10.sp,
                                fontFamily: 'Satoshi',
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Next Button at the end of scrollable content
                    Padding(
                      padding: EdgeInsets.fromLTRB(29.sw, 42.sh, 29.sw, 42.sh),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _AnimatedNextButton(
                          onTap: () {
                            if (_titleController.text.isEmpty || (_image == null && widget.editingRecipe?.imageUrl == null)) {
                              Toaster.show(context, 'Please enter a title and select an image', isError: true);
                              return;
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UploadRecipeStep2(
                                  title: _titleController.text,
                                  image: _image,
                                  editingRecipe: widget.editingRecipe,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StaggeredFadeIn extends StatelessWidget {
  final Widget child;
  const _StaggeredFadeIn({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _AnimatedNextButton extends StatefulWidget {
  final VoidCallback onTap;
  const _AnimatedNextButton({required this.onTap});

  @override
  State<_AnimatedNextButton> createState() => _AnimatedNextButtonState();
}

class _AnimatedNextButtonState extends State<_AnimatedNextButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orange = const Color(0xFFF2894F);
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 184.sw,
          height: 62.sh,
          decoration: BoxDecoration(
            color: orange,
            borderRadius: BorderRadius.circular(20.sw),
            boxShadow: [
              BoxShadow(
                color: orange.withValues(alpha:0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Next Step',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Satoshi',
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(width: 12.sw),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackgroundPatterns extends StatelessWidget {
  const _BackgroundPatterns();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}



