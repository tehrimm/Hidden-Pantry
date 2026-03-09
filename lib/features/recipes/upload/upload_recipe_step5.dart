import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_service.dart';
import 'package:hidden_pantry_app/core/widgets/main_navigation_shell.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';


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
  final Recipe? editingRecipe;

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
    this.editingRecipe,
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
  final Color bg = const Color(0xFFFFF3EB);
  final RecipeService _recipeService = RecipeService();
  
  bool _isSubmitting = false;
  late bool _isPublic;

  @override
  void initState() {
    super.initState();
    _isPublic = widget.editingRecipe?.isPublic ?? false;

    // Pre-fill nutrition controllers
    _controllers.forEach((key, controller) {
      final val = widget.editingRecipe?.nutrition?[key];
      if (val != null) {
        controller.text = RegExp(r'[\d.]+').firstMatch(val)?.group(0) ?? '';
      }
    });
  }

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
        recipeId: widget.editingRecipe?.id,
        title: widget.title,
        mainImage: widget.image,
        prepTime: widget.prepTime,
        cookTime: widget.cookTime,
        servings: widget.servings,
        difficulty: widget.difficulty ?? 'Easy',
        tags: widget.tags,
        ingredients: widget.ingredients,
        steps: widget.steps,
        nutrition: nutrition,
        isPublic: _isPublic,
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
            const _BackgroundPatterns(),
            SafeArea(
              child: Column(
                children: [
                  SizedBox(height: 12.sh),
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
                              '5/5',
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
                        'Nutrition',
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
                    child: ListView(
                      padding: EdgeInsets.only(top: 20.sh, bottom: 120.sh, left: 30.sw, right: 30.sw),
                      children: [
                        Text(
                          'Enter nutritional information per serving (optional).',
                          style: TextStyle(
                            color: purple.withValues(alpha:0.6),
                            fontSize: 14.sp,
                            fontFamily: 'Satoshi',
                          ),
                        ),
                        SizedBox(height: 30.sh),
                        _buildVisibilityToggle(),
                        SizedBox(height: 30.sh),
                        ..._controllers.keys.map((key) => _buildNutritionField(key)).toList(),
 
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 42.sh),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: _isSubmitting ? null : _submit,
                                  child: Container(
                                    height: 62.sh,
                                    decoration: BoxDecoration(
                                      color: orange,
                                      borderRadius: BorderRadius.circular(20.sw),
                                    ),
                                    child: _isSubmitting
                                        ? Center(
                                            child: SizedBox(
                                              width: 24.sw,
                                              height: 24.sh,
                                              child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                'Submit',
                                                style: TextStyle(
                                                  color: const Color(0xFFFFF2EA),
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
            ),
 
            if (_isSubmitting)
              Container(
                color: Colors.black.withValues(alpha:0.3),
                child: Center(
                  child: CircularProgressIndicator(color: orange),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisibilityToggle() {
    return Container(
      padding: EdgeInsets.all(20.sw),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20.sw),
        border: Border.all(color: _isPublic ? orange.withValues(alpha: 0.3) : Colors.transparent),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.sw),
            decoration: BoxDecoration(
              color: _isPublic ? orange.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isPublic ? Icons.public_rounded : Icons.public_off_rounded,
              color: _isPublic ? orange : purple.withValues(alpha: 0.3),
              size: 20.sw,
            ),
          ),
          SizedBox(width: 16.sw),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Public Visibility",
                  style: TextStyle(color: purple, fontSize: 16.sp, fontWeight: FontWeight.bold, fontFamily: 'Satoshi'),
                ),
                Text(
                  _isPublic ? "Visible to everyone" : "Private (Author only)",
                  style: TextStyle(color: purple.withValues(alpha: 0.5), fontSize: 12.sp, fontFamily: 'Satoshi'),
                ),
              ],
            ),
          ),
          Switch(
            value: _isPublic,
            onChanged: (v) => setState(() => _isPublic = v),
            activeThumbColor: orange,
            activeTrackColor: orange.withValues(alpha: 0.1),
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
      padding: EdgeInsets.only(bottom: 16.sh),
      child: Container(
        height: 62.sh,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(15.sw),
        ),
        padding: EdgeInsets.symmetric(horizontal: 20.sw),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controllers[label],
                keyboardType: TextInputType.number,
                style: TextStyle(color: purple, fontSize: 16.sp, fontWeight: FontWeight.bold, fontFamily: 'Satoshi'),
                decoration: InputDecoration(
                  hintText: label,
                  hintStyle: TextStyle(color: purple.withValues(alpha:0.4), fontSize: 16.sp, fontFamily: 'Satoshi'),
                  border: InputBorder.none,
                ),
              ),
            ),
            Text(
              unit,
              style: TextStyle(color: purple.withValues(alpha:0.6), fontSize: 14.sp, fontWeight: FontWeight.bold, fontFamily: 'Satoshi'),
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
