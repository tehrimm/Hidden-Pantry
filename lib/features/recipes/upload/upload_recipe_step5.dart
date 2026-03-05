import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_service.dart';
import 'package:hidden_pantry_app/core/widgets/main_navigation_shell.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';

class UploadRecipeStep5 extends StatefulWidget {
  final String title;
  final File? image;
  final int prepTime;
  final int cookTime;
  final int servings;
  final String? difficulty;
  final List<String> tags;
  final List<Map<String, String>> ingredients;
  final List<DirectionStep> steps;

  const UploadRecipeStep5({
    super.key,
    required this.title,
    this.image,
    required this.prepTime,
    required this.cookTime,
    required this.servings,
    this.difficulty,
    required this.tags,
    required this.ingredients,
    required this.steps,
  });

  @override
  State<UploadRecipeStep5> createState() => _UploadRecipeStep5State();
}

class _UploadRecipeStep5State extends State<UploadRecipeStep5> {
  final Map<String, TextEditingController> _controllers = {
    'Calories': TextEditingController(),
    'Protein': TextEditingController(),
    'Carbs': TextEditingController(),
    'Total Fat': TextEditingController(),
    'Sat. Fat': TextEditingController(),
    'Sugar': TextEditingController(),
    'Sodium': TextEditingController(),
  };

  final Color purple = const Color(0xFF462F4D);
  final Color orange = const Color(0xFFF2894F);
  final Color cardBg = const Color(0xFFF9E3D5);
  final RecipeService _recipeService = RecipeService();
  
  bool _isSubmitting = false;

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    
    try {
      final Map<String, String> nutrition = {};
      _controllers.forEach((key, controller) {
        if (controller.text.isNotEmpty) {
          String unit = 'g';
          if (key == 'Calories') unit = 'kcal';
          if (key == 'Sodium') unit = 'mg';
          nutrition[key] = "${controller.text} $unit";
        }
      });

      await _recipeService.uploadFullRecipe(
        title: widget.title,
        mainImage: widget.image,
        prepTime: widget.prepTime,
        cookTime: widget.cookTime,
        servings: widget.servings,
        difficulty: widget.difficulty,
        tags: widget.tags,
        ingredients: widget.ingredients,
        steps: widget.steps,
        nutrition: nutrition,
      );

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Success', style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontFamily: 'Satoshi')),
            content: Text('Your recipe has been uploaded successfully!', style: TextStyle(color: purple, fontFamily: 'Satoshi')),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const MainNavigationShell()),
                    (route) => false,
                  );
                },
                child: Text('Awesome', style: TextStyle(color: orange, fontWeight: FontWeight.bold, fontFamily: 'Satoshi')),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Toaster.show(context, 'Error uploading recipe: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
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
                    const SizedBox(width: 40),
                    Text(
                      'Add Recipe',
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
                          '5/5',
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
                    'Nutrition',
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
                child: ListView(
                  padding: const EdgeInsets.only(top: 20, bottom: 120, left: 27, right: 27),
                  children: [
                    Text(
                      'Enter nutritional information per serving (optional).',
                      style: TextStyle(
                        color: purple.withValues(alpha:0.6),
                        fontSize: 14,
                        fontFamily: 'Satoshi',
                      ),
                    ),
                    const SizedBox(height: 30),
                    ..._controllers.keys.map((key) => _buildNutritionField(key)).toList(),
                  ],
                ),
              ),
            ],
          ),

          if (_isSubmitting)
            Container(
              color: Colors.black.withValues(alpha:0.3),
              child: Center(
                child: CircularProgressIndicator(color: orange),
              ),
            ),

          // Bottom Buttons
          Positioned(
            bottom: 42,
            left: 30,
            right: 29,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 52,
                    height: 53,
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(Icons.arrow_back_ios_new, size: 16, color: purple),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: GestureDetector(
                    onTap: _isSubmitting ? null : _submit,
                    child: Container(
                      height: 62,
                      decoration: BoxDecoration(
                        color: orange,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isSubmitting ? 'Uploading...' : 'Submit Recipe',
                            style: const TextStyle(
                              color: Color(0xFFFFF2EA),
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Satoshi',
                            ),
                          ),
                          if (!_isSubmitting) ...[
                            const SizedBox(width: 10),
                            const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                          ],
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
    );
  }

  Widget _buildNutritionField(String label) {
    String unit = 'g';
    if (label == 'Calories') unit = 'kcal';
    if (label == 'Sodium') unit = 'mg';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        height: 62,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(15),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controllers[label],
                keyboardType: TextInputType.number,
                style: TextStyle(color: purple, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Satoshi'),
                decoration: InputDecoration(
                  hintText: label,
                  hintStyle: TextStyle(color: purple.withValues(alpha:0.4), fontSize: 16, fontFamily: 'Satoshi'),
                  border: InputBorder.none,
                ),
              ),
            ),
            Text(
              unit,
              style: TextStyle(color: purple.withValues(alpha:0.6), fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Satoshi'),
            ),
          ],
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



