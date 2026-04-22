import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'add_ingredient_screen.dart';
import 'upload_recipe_step4.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';


class UploadRecipeStep3 extends StatefulWidget {
  final String title;
  final File? image;
  final int prepTime;
  final int cookTime;
  final int servings;
  final String? difficulty;
  final List<String> tags;
  final Recipe? editingRecipe;

  const UploadRecipeStep3({
    super.key,
    required this.title,
    this.image,
    required this.prepTime,
    required this.cookTime,
    required this.servings,
    this.difficulty,
    required this.tags,
    this.editingRecipe,
  });

  @override
  State<UploadRecipeStep3> createState() => _UploadRecipeStep3State();
}

class _UploadRecipeStep3State extends State<UploadRecipeStep3> {
  late final List<Map<String, String>> _ingredients;

  @override
  void initState() {
    super.initState();
    _ingredients = widget.editingRecipe?.ingredients.map((ing) {
          return {
            'name': ing.name,
            'quantity': ing.unit.isEmpty ? ing.quantity.toString() : "${ing.quantity} ${ing.unit}",
          };
        }).toList() ??
        [];
  }

  final Color purple = const Color(0xFF462F4D);
  final Color orange = const Color(0xFFEF8A54);
  final Color cardBg = const Color(0xFFF9E3D5);

  void _addIngredient() async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(builder: (_) => const AddIngredientScreen()),
    );

    if (result != null) {
      setState(() {
        _ingredients.add(result);
      });
    }
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredients.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3EB),
      body: Stack(
        children: [
          PatternBackground(),
          Column(
            children: [
              SizedBox(height: 50.sh),
              // Header
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
                          '3/5',
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

              // Scrollable content
              Expanded(
                child: ListView(
                  padding: EdgeInsets.only(top: 20.sh, bottom: 120.sh),
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 27.sw),
                      child: Text(
                        'Ingredients',
                        style: TextStyle(
                          color: purple,
                          fontSize: 40.sp,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                          fontFamily: 'Satoshi',
                        ),
                      ),
                    ),
                    SizedBox(height: 30.sh),

                    // Ingredient list
                    ..._ingredients.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final ingredient = entry.value;
                      return Padding(
                        padding: EdgeInsets.fromLTRB(30.sw, 0, 30.sw, 8.sh),
                        child: Container(
                          height: 70.sh,
                          clipBehavior: Clip.hardEdge,
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(20.sw),
                          ),
                          child: Stack(
                            children: [
                              // Divider line
                              Positioned(
                                left: 174.sw,
                                top: 0,
                                bottom: 0,
                                child: Container(
                                  width: 1,
                                  color: purple.withValues(alpha: 0.1),
                                ),
                              ),
                              Positioned.fill(
                                child: Row(
                                  children: [
                                    // Name
                                    Expanded(
                                      flex: 174,
                                      child: Text(
                                        ingredient['name'] ?? '',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: purple,
                                          fontSize: 15.sp,
                                          fontFamily: 'Satoshi',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    // Quantity
                                    Expanded(
                                      flex: 158,
                                      child: Text(
                                        ingredient['quantity'] ?? '',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: purple,
                                          fontSize: 15.sp,
                                          fontFamily: 'Satoshi',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    // Remove button
                                    Padding(
                                      padding: EdgeInsets.only(right: 8.sw),
                                      child: IconButton(
                                        icon: Icon(Icons.close, size: 18.sw),
                                        onPressed: () => _removeIngredient(idx),
                                        color: purple.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),

                    // Add button
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 30.sw, vertical: 8.sh),
                       child: GestureDetector(
                        onTap: _addIngredient,
                        child: Container(
                          height: 62.sh,
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(20.sw),
                          ),
                          child: Padding(
                            padding: EdgeInsets.only(left: 30.sw),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add, color: purple, size: 18.sw),
                                SizedBox(width: 8.sw),
                                Text(
                                  'Add Ingredients',
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
                    ),

                    // Bottom buttons inside the scrollable area
                    Padding(
                      padding: EdgeInsets.fromLTRB(30.sw, 42.sh, 29.sw, 42.sh),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _AnimatedNextButton(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UploadRecipeStep4(
                                  title: widget.title,
                                  image: widget.image,
                                  prepTime: widget.prepTime,
                                  cookTime: widget.cookTime,
                                  servings: widget.servings,
                                  difficulty: widget.difficulty,
                                  tags: widget.tags,
                                  ingredients: _ingredients,
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
