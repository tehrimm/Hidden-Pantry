import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'upload_recipe_step5.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';

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
  final ImagePicker _picker = ImagePicker();

  final Color purple = const Color(0xFF462F4D);
  final Color orange = const Color(0xFFEF8A54);
  final Color cardBg = const Color(0xFFF9E3D5);
  final Color bg = const Color(0xFFFFF3EB);

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
          imageUrl: s['imageUrl'],
        );
      }).toList();
    } else {
      _steps = [DirectionStep(id: DateTime.now().millisecondsSinceEpoch.toString())];
    }
  }

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
                if (image != null) setState(() => _steps[index].image = File(image.path));
              }),
              SizedBox(height: 12.sh),
              _sourceTile(Icons.camera_alt_rounded, "Camera", () async {
                final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
                if (photo != null) setState(() => _steps[index].image = File(photo.path));
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

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(30.sw),
        ),
        child: Stack(
          children: [
            PatternBackground(),
            Column(
              children: [
                SizedBox(height: 50.sh),
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
                        height: math.max(36.0, 42.sh),
                        decoration: BoxDecoration(
                          color: purple,
                          borderRadius: BorderRadius.circular(10.sw),
                        ),
                        child: Center(
                          child: Text(
                            '4/5',
                            style: TextStyle(
                              color: const Color(0xFFFFF2EA),
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
                SizedBox(height: 20.sh),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 27.sw),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Direction',
                      style: TextStyle(
                        color: purple,
                        fontSize: 40.sp,
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
                      padding: EdgeInsets.only(top: 20.sh, bottom: 120.sh),
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
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButtons(int index) {
    return Container(
      key: const ValueKey('nav_buttons'),
      padding: EdgeInsets.fromLTRB(30.sw, 42.sh, 29.sw, 42.sh),
      child: Align(
        alignment: Alignment.centerRight,
        child: _AnimatedNextButton(
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
        ),
      ),
    );
  }

  Widget _buildStepItem(int index) {
    final step = _steps[index];
    return Container(
      key: ValueKey(step.id),
      margin: EdgeInsets.symmetric(horizontal: 20.sw, vertical: 10.sh),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 10.sw,
            top: 40.sh,
            child: ReorderableDragStartListener(
              index: index,
              child: Icon(Icons.drag_handle, color: const Color(0xFFD9D9D9), size: 24.sw),
            ),
          ),
          Positioned(
            left: 10.sw,
            top: 5.sh,
            child: Container(
              width: 24.sw,
              height: 24.sw,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12.sw),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: purple,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Satoshi',
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(left: 44.sw, right: 30.sw),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(minHeight: math.max(70.0, 70.sh)),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20.sw),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 16.sw, vertical: 12.sh),
                  child: TextField(
                    onChanged: (val) => setState(() => step.text = val),
                    maxLines: null,
                    maxLength: 500,
                    style: TextStyle(color: purple, fontSize: 15.sp, fontFamily: 'Satoshi'),
                    decoration: InputDecoration(
                      hintText: 'Direction ${index + 1}',
                      hintStyle: TextStyle(
                        color: purple.withValues(alpha: 0.5),
                        fontSize: 15.sp,
                        fontFamily: 'Satoshi',
                      ),
                      border: InputBorder.none,
                      counterText: '',
                    ),
                  ),
                ),
                SizedBox(height: 4.sh),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${step.text.length}/500',
                    style: TextStyle(
                      color: purple,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Satoshi',
                    ),
                  ),
                ),
                SizedBox(height: 10.sh),
                GestureDetector(
                  onTap: () => _pickStepImage(index),
                  child: Container(
                    width: 107.sw,
                    height: math.max(75.0, 85.sh),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20.sw),
                      image: step.image != null
                          ? DecorationImage(image: FileImage(step.image!), fit: BoxFit.cover)
                          : (step.imageUrl != null
                              ? DecorationImage(image: NetworkImage(step.imageUrl!), fit: BoxFit.cover)
                              : null),
                    ),
                    child: step.image == null && step.imageUrl == null
                        ? Center(child: Icon(Icons.camera_alt_outlined, color: purple, size: 24.sw))
                        : null,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 0,
            top: 15.sh,
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
              icon: Icon(Icons.more_vert, color: purple, size: 20.sw),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(int index) {
    return Container(
      key: const ValueKey('add_button'),
      padding: EdgeInsets.symmetric(horizontal: 30.sw, vertical: 10.sh),
      child: GestureDetector(
        onTap: _addStep,
        child: Container(
          height: math.max(62.0, 62.sh),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20.sw),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, color: purple, size: 18.sw),
                SizedBox(width: 8.sw),
                Text(
                  'Add Direction',
                  style: TextStyle(
                    color: purple,
                    fontSize: 15.sp,
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
    final orange = const Color(0xFFEF8A54);
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 184.sw,
          height: math.max(62.0, 62.sh),
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
