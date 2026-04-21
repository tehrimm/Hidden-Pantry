import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'upload_recipe_step2.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';


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
                if (image != null) setState(() => _image = File(image.path));
              }),
              SizedBox(height: 12.sh),
              _sourceTile(Icons.camera_alt_rounded, "Camera", () async {
                final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
                if (photo != null) setState(() => _image = File(photo.path));
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
  final Color orange = const Color(0xFFF2894F);
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
          const _BackgroundPatterns(),

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
                                          child: Image.network(widget.editingRecipe!.imageUrl!, fit: BoxFit.cover),
                                        )
                                      : Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.add_photo_alternate_rounded, size: 48.sw, color: purple.withValues(alpha: 0.4)),
                                            SizedBox(height: 12.sh),
                                            Text('Add Recipe Photo', style: TextStyle(color: purple.withValues(alpha: 0.4), fontSize: 16.sp, fontWeight: FontWeight.w900, fontFamily: 'Satoshi')),
                                            Text('Make them hungry!', style: TextStyle(color: purple.withValues(alpha: 0.25), fontSize: 12.sp, fontFamily: 'Satoshi')),
                                          ],
                                        )),
                            ),
                          ),
                          SizedBox(height: 5.sh),
                          Text(
                            '*maximum size 2MB',
                            style: TextStyle(
                              color: purple,
                              fontSize: 9.sp,
                              fontFamily: 'Satoshi',
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Next Button at the end of scrollable content
                    Padding(
                      padding: EdgeInsets.fromLTRB(29.sw, 42.sh, 29.sw, 42.sh),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
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
                          child: Container(
                            width: 220.sw,
                            height: 62.sh,
                            decoration: BoxDecoration(
                              color: orange,
                              borderRadius: BorderRadius.circular(20.sw),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Next',
                                  style: TextStyle(
                                    color: Color(0xFFFFF2EA),
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Satoshi',
                                  ),
                                ),
                                SizedBox(width: 10.sw),
                                Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16.sw),
                              ],
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
        ],
      ),
    );
  }
}

class _BackgroundPatterns extends StatelessWidget {
  const _BackgroundPatterns();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: -154,
            top: -14,
            child: Transform.rotate(
              angle: 21 * math.pi / 180,
              child: Container(
                width: 271,
                height: 159,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFF5DDCE)),
                  borderRadius: const BorderRadius.all(Radius.elliptical(136, 80)),
                ),
              ),
            ),
          ),
          Positioned(
            left: -149,
            top: -100,
            child: Transform.rotate(
              angle: 4 * math.pi / 180,
              child: Container(
                width: 303,
                height: 329,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFF5DDCE)),
                  borderRadius: const BorderRadius.all(Radius.elliptical(152, 165)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}



