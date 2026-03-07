import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'add_ingredient_screen.dart';
import 'upload_recipe_step4.dart';

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
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3EB),
      body: Stack(
        children: [
          const _BackgroundPatterns(),
          Column(
            children: [
              const SizedBox(height: 50),
              // Header
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
                          '3/5',
                          style: TextStyle(
                            color: const Color(0xFFFFF2EA),
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

              // Scrollable content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(top: 20, bottom: 120),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 27),
                      child: Text(
                        'Ingredients',
                        style: TextStyle(
                          color: purple,
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                          fontFamily: 'Satoshi',
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Ingredient list
                    ..._ingredients.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final ingredient = entry.value;
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(30, 0, 30, 8),
                        child: Container(
                          height: 70,
                          clipBehavior: Clip.hardEdge,
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Stack(
                            children: [
                              // Divider line
                              Positioned(
                                left: 174,
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
                                          fontSize: 15,
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
                                          fontSize: 15,
                                          fontFamily: 'Satoshi',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    // Remove button
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: IconButton(
                                        icon: const Icon(Icons.close, size: 18),
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
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 8),
                       child: GestureDetector(
                        onTap: _addIngredient,
                        child: Container(
                          height: 62,
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 30),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add, color: purple, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Add Ingredients',
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
                    ),

                    // Bottom buttons inside the scrollable area
                    Padding(
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
