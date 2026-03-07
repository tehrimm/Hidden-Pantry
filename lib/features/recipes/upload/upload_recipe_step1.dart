import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'upload_recipe_step2.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';

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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF462F4D)),
              title: const Text('Take a Photo', style: TextStyle(color: Color(0xFF462F4D), fontFamily: 'Satoshi')),
              onTap: () async {
                Navigator.pop(context);
                final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
                if (photo != null) {
                  setState(() => _image = File(photo.path));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF462F4D)),
              title: const Text('Choose from Gallery', style: TextStyle(color: Color(0xFF462F4D), fontFamily: 'Satoshi')),
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
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3EB),
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Background Patterns
          const _BackgroundPatterns(),

          Column(
            children: [
              const SizedBox(height: 50),
              // Fixed Header area
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 29),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    BackButtonWidget(color: purple),
                    Text(
                      widget.editingRecipe != null ? 'Edit Recipe' : 'Add Recipe',
                      style: TextStyle(
                        color: purple,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Satoshi',
                      ),
                    ),
                    Container(
                      width: 69,
                      height: 42,
                      decoration: BoxDecoration(
                        color: purple,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text(
                          '1/5',
                          style: TextStyle(
                            color: Color(0xFFFFF2EA),
                            fontSize: 12,
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
                  padding: const EdgeInsets.only(top: 20, bottom: 120),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 29),
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
                          const SizedBox(height: 32),
                          Container(
                            height: 70,
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 25),
                            alignment: Alignment.centerLeft,
                            child: TextField(
                              controller: _titleController,
                              style: TextStyle(
                                color: purple,
                                fontSize: 15,
                                fontFamily: 'Satoshi',
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Enter recipe title',
                                border: InputBorder.none,
                                hintStyle: TextStyle(color: Color(0x66462F4D)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 23),
                          GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              width: double.infinity,
                              height: 294,
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(20),
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
                                              Icon(Icons.file_upload_outlined, size: 40, color: purple),
                                              const SizedBox(height: 15),
                                              Text(
                                                'Upload your recipe picture',
                                                style: TextStyle(
                                                  color: purple,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  letterSpacing: 0.2,
                                                  fontFamily: 'Satoshi',
                                                ),
                                              ),
                                              const SizedBox(height: 5),
                                              Text(
                                                '*maximum size 2MB',
                                                style: TextStyle(
                                                  color: purple,
                                                  fontSize: 9,
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
                      padding: const EdgeInsets.fromLTRB(29, 42, 29, 42),
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
                            width: 220,
                            height: 62,
                            decoration: BoxDecoration(
                              color: orange,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text(
                                  'Next',
                                  style: TextStyle(
                                    color: Color(0xFFFFF2EA),
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Satoshi',
                                  ),
                                ),
                                SizedBox(width: 10),
                                Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
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



