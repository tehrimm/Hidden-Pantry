import 'dart:io';
import 'dart:math' as math;
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
      backgroundColor: const Color(0xFFF9E3D5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30.sw)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt, color: Color(0xFF462F4D), size: 24.sw),
              title: Text('Take a Photo', style: TextStyle(color: Color(0xFF462F4D), fontFamily: 'Satoshi', fontSize: 16.sp)),
              onTap: () async {
                Navigator.pop(context);
                final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
                if (photo != null) {
                  setState(() => _image = File(photo.path));
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: Color(0xFF462F4D), size: 24.sw),
              title: Text('Choose from Gallery', style: TextStyle(color: Color(0xFF462F4D), fontFamily: 'Satoshi', fontSize: 16.sp)),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                if (image != null) {
                  setState(() => _image = File(image.path));
                }
              },
            ),
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
                              width: double.infinity,
                              height: 294.sh,
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(20.sw),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: _image != null
                                    ? Image.file(_image!, fit: BoxFit.cover)
                                    : (widget.editingRecipe?.imageUrl != null
                                        ? Image.network(widget.editingRecipe!.imageUrl!, fit: BoxFit.cover)
                                        : Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.file_upload_outlined, size: 40.sw, color: purple),
                                              SizedBox(height: 15.sh),
                                              Text(
                                                'Upload your recipe picture',
                                                style: TextStyle(
                                                  color: purple,
                                                  fontSize: 12.sp,
                                                  fontWeight: FontWeight.w500,
                                                  letterSpacing: 0.2,
                                                  fontFamily: 'Satoshi',
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
                                          )),
                              ),
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



