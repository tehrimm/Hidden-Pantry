import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'upload_recipe_step5.dart';

class UploadRecipeStep4 extends StatefulWidget {
  final String title;
  final File? image;
  final int prepTime;
  final int cookTime;
  final int servings;
  final String? difficulty;
  final List<String> tags;
  final List<Map<String, String>> ingredients;
  final Recipe? editingRecipe;

  const UploadRecipeStep4({
    super.key,
    required this.title,
    this.image,
    required this.prepTime,
    required this.cookTime,
    required this.servings,
    this.difficulty,
    required this.tags,
    required this.ingredients,
    this.editingRecipe,
  });

  @override
  State<UploadRecipeStep4> createState() => _UploadRecipeStep4State();
}

class _UploadRecipeStep4State extends State<UploadRecipeStep4> {
  late final List<DirectionStep> _steps;

  @override
  void initState() {
    super.initState();
    if (widget.editingRecipe?.stepsDetailed != null && widget.editingRecipe!.stepsDetailed!.isNotEmpty) {
      _steps = widget.editingRecipe!.stepsDetailed!.asMap().entries.map((entry) {
        final idx = entry.key;
        final s = entry.value;
        return DirectionStep(
          id: DateTime.now().millisecondsSinceEpoch.toString() + idx.toString(),
          text: s['text'] ?? '',
          imageUrl: s['imageUrl'], // Preserve remote URL
        );
      }).toList();
    } else {
      _steps = [DirectionStep(id: DateTime.now().millisecondsSinceEpoch.toString())];
    }
  }
  final ImagePicker _picker = ImagePicker();

  final Color purple = const Color(0xFF462F4D);
  final Color orange = const Color(0xFFF2894F);
  final Color cardBg = const Color(0xFFF9E3D5);
  final Color bg = const Color(0xFFFFF3EB);

  void _addStep() {
    setState(() {
      _steps.add(DirectionStep(
        id: DateTime.now().millisecondsSinceEpoch.toString() + _steps.length.toString(),
      ));
    });
  }

  void _removeStep(int index) {
    if (_steps.length > 1) {
      setState(() {
        _steps.removeAt(index);
      });
    } else {
      setState(() {
        _steps[0] = DirectionStep(id: DateTime.now().millisecondsSinceEpoch.toString());
      });
    }
  }

  Future<void> _pickStepImage(int index) async {
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
                  setState(() => _steps[index].image = File(photo.path));
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
                  setState(() => _steps[index].image = File(image.path));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // Source button previously used for inline camera/gallery; replaced by Step 1-style bottom sheet

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Stack(
          children: [
            const _BackgroundPatterns(),
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 12),
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
                              '4/5',
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
 
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 27),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Direction',
                        style: TextStyle(
                          color: purple,
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                          fontFamily: 'Satoshi',
                        ),
                      ),
                    ),
                  ),
 
                  Expanded(
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        canvasColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                      ),
                      child: ReorderableListView.builder(
                        padding: const EdgeInsets.only(top: 20, bottom: 120),
                        itemCount: _steps.length + 2,
                        itemBuilder: (context, index) {
                          if (index == _steps.length) {
                            return _buildAddButton(index);
                          }
                          if (index == _steps.length + 1) {
                            return _buildNavigationButtons(index);
                          }
                          return _buildStepItem(index);
                        },
                        onReorder: (oldIndex, newIndex) {
                          if (newIndex > oldIndex) newIndex -= 1;
                          if (newIndex >= _steps.length) return;
                          if (oldIndex >= _steps.length) return;
 
                          setState(() {
                            final step = _steps.removeAt(oldIndex);
                            _steps.insert(newIndex, step);
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButtons(int index) {
    return Container(
      key: const ValueKey('nav_buttons'),
      padding: const EdgeInsets.fromLTRB(30, 42, 29, 42),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UploadRecipeStep5(
                      title: widget.title,
                      image: widget.image,
                      prepTime: widget.prepTime,
                      cookTime: widget.cookTime,
                      servings: widget.servings,
                      difficulty: widget.difficulty,
                      tags: widget.tags,
                      ingredients: widget.ingredients,
                      steps: _steps,
                      editingRecipe: widget.editingRecipe,
                    ),
                  ),
                );
              },
              child: Container(
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
        ],
      ),
    );
  }

  Widget _buildStepItem(int index) {
    final step = _steps[index];
    return Container(
      key: ValueKey(step.id),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Drag handle area (Implicitly handled by ReorderableListView but we add dummy icon)
          Positioned(
            left: 10,
            top: 40,
            child: ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_handle, color: Color(0xFFD9D9D9), size: 24),
            ),
          ),

          // Circle with number
          Positioned(
            left: 10,
            top: 5,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: purple,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Satoshi',
                  ),
                ),
              ),
            ),
          ),

          // Actual Content Box
          Padding(
            padding: const EdgeInsets.only(left: 44, right: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Direction Text Input
                Container(
                  constraints: const BoxConstraints(minHeight: 70),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: TextField(
                    onChanged: (val) => setState(() => step.text = val),
                    maxLines: null,
                    maxLength: 500,
                    style: TextStyle(color: purple, fontSize: 15, fontFamily: 'Satoshi'),
                    decoration: InputDecoration(
                      hintText: 'Direction ${index + 1}',
                      hintStyle: TextStyle(
                        color: purple.withValues(alpha: 0.5),
                        fontSize: 15,
                        fontFamily: 'Satoshi',
                      ),
                      border: InputBorder.none,
                      counterText: '', // We use custom counter
                    ),
                  ),
                ),

                // Character Counter
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${step.text.length}/500',
                    style: TextStyle(
                      color: purple,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Satoshi',
                    ),
                  ),
                ),

                // Optional Image
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => _pickStepImage(index),
                  child: Container(
                    width: 107,
                    height: 85,
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      image: step.image != null
                          ? DecorationImage(image: FileImage(step.image!), fit: BoxFit.cover)
                          : (step.imageUrl != null
                              ? DecorationImage(image: NetworkImage(step.imageUrl!), fit: BoxFit.cover)
                              : null),
                    ),
                    child: step.image == null && step.imageUrl == null
                        ? Center(child: Icon(Icons.camera_alt_outlined, color: purple, size: 24))
                        : null,
                  ),
                ),
              ],
            ),
          ),

          // 3 dots menu (Delete)
          Positioned(
            right: 0,
            top: 15,
            child: PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'delete') _removeStep(index);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete Step'),
                ),
              ],
              icon: Icon(Icons.more_vert, color: purple, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(int index) {
    return Container(
      key: const ValueKey('add_button'),
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
      child: GestureDetector(
        onTap: _addStep,
        child: Container(
          height: 62,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, color: purple, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Add Direction',
                  style: TextStyle(
                    color: purple,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Satoshi',
                  ),
                ),
              ],
            ),
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
