import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'add_ingredient_screen.dart';
import 'upload_recipe_step4.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';


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
  final Color orange = const Color(0xFFF2894F);
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
          const _BackgroundPatterns(),
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
                              child: Container(
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
                        ],
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
            left: -154.sw,
            top: -14.sh,
            child: Transform.rotate(
              angle: 21 * math.pi / 180,
              child: Container(
                width: 271.sw,
                height: 159.sh,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFF5DDCE)),
                  borderRadius: BorderRadius.all(Radius.elliptical(136.sw, 80.sh)),
                ),
              ),
            ),
          ),
          Positioned(
            left: -149.sw,
            top: -100.sh,
            child: Transform.rotate(
              angle: 4 * math.pi / 180,
              child: Container(
                width: 303.sw,
                height: 329.sh,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFF5DDCE)),
                  borderRadius: BorderRadius.all(Radius.elliptical(152.sw, 165.sh)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
