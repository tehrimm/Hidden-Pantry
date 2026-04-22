import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'upload_recipe_step3.dart';

class UploadRecipeStep2 extends StatefulWidget {
  final String title;
  final File? image;
  final Recipe? editingRecipe;

  const UploadRecipeStep2({
    super.key,
    required this.title,
    this.image,
    this.editingRecipe,
  });

  @override
  State<UploadRecipeStep2> createState() => _UploadRecipeStep2State();
}

class _UploadRecipeStep2State extends State<UploadRecipeStep2> {
  late int _prepTime;
  late int _cookTime;
  late int _servings;
  String? _difficulty;
  late final List<String> _selectedTags;

  @override
  void initState() {
    super.initState();
    _prepTime = widget.editingRecipe?.prepMinutes ?? 15;
    _cookTime = widget.editingRecipe?.cookMinutes ?? 40;
    _servings = widget.editingRecipe?.baseServings ?? 2;
    _difficulty = widget.editingRecipe?.difficulty;
    _selectedTags = List<String>.from(widget.editingRecipe?.tags ?? []);
  }

  final Map<String, List<String>> _allCategories = {
    'Time': [
      '15-minutes-or-less',
      '30-minutes-or-less',
      '60-minutes-or-less',
      '4-hours-or-less',
    ],
    'Dietary': [
      'vegetarian',
      'vegan',
      'diabetic',
      'gluten-free',
      'free-of-something',
    ],
    'Nutrition': [
      'healthy',
      'high-protein',
      'low-calorie',
      'low-carb',
      'low-cholesterol',
      'low-fat',
      'low-sodium',
    ],
    'Cuisine': [
      'american',
      'australian',
      'north-american',
      'south-west-pacific',
    ],
    'Meat & Protein': [
      'beef',
      'chicken',
      'ground-beef',
      'meat',
      'pork',
    ],
    'Seafood': [
      'crab',
      'seafood',
      'shellfish',
      'shrimp',
    ],
    'Vegetables & Grains': [
      'beans',
      'grains',
      'pasta-rice-and-grains',
      'potatoes',
      'vegetables',
    ],
    'Dairy & Eggs': [
      'cheese',
      'eggs',
    ],
    'Course': [
      'breakfast',
      'brunch',
      'lunch',
      'main-dish',
      'side-dishes',
      'desserts',
      'salads',
      'soups-stews',
    ],
    'Dish Type': [
      'breads',
      'candy',
      'casseroles',
      'cookies-and-brownies',
      'muffins',
      'one-dish-meal',
    ],
    'Equipment': [
      'crock-pot-slow-cooker',
      'no-cook',
      'oven',
      'refrigerator',
      'stove-top',
    ],
    'Occasion': [
      'comfort-food',
      'dinner-party',
      'for-large-groups',
      'picnic',
      'weeknight',
    ],
    'Season': [
      'fall',
      'spring',
      'summer',
      'winter',
    ],
  };

  final Color purple = const Color(0xFF462F4D);
  final Color orange = const Color(0xFFEF8A54);
  final Color cardBg = const Color(0xFFF9E3D5);
  final Color textBrown = const Color(0xFF433020);

  String _beautify(String t) {
    if (t.contains('-')) {
      return t.split('-').map((s) {
        if (s.isEmpty) return "";
        return s[0].toUpperCase() + s.substring(1);
      }).join(' ');
    }
    if (t.isEmpty) return t;
    return t[0].toUpperCase() + t.substring(1);
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Time': return Icons.timer_outlined;
      case 'Dietary': return Icons.spa_outlined;
      case 'Nutrition': return Icons.analytics_outlined;
      case 'Cuisine': return Icons.public;
      case 'Meat & Protein': return Icons.kebab_dining;
      case 'Seafood': return Icons.set_meal;
      case 'Vegetables & Grains': return Icons.eco;
      case 'Dairy & Eggs': return Icons.egg_outlined;
      case 'Course': return Icons.restaurant_menu;
      case 'Dish Type': return Icons.flatware;
      case 'Equipment': return Icons.microwave_outlined;
      case 'Occasion': return Icons.celebration;
      case 'Season': return Icons.wb_sunny_outlined;
      default: return Icons.tag;
    }
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
                        // Step Indicator
                        Container(
                          width: 69.sw,
                          height: 42.sh,
                          decoration: BoxDecoration(
                            color: purple,
                            borderRadius: BorderRadius.circular(10.sw),
                          ),
                          child: Center(
                            child: Text(
                              '2/5',
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

                  // Scrollable Content
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.only(top: 20.sh, bottom: 120.sh),
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 27.sw),
                          child: _StaggeredFadeIn(
                            child: Text(
                              'Information',
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
                        SizedBox(height: 30.sh),

                        _StaggeredFadeIn(
                          delay: 1,
                          child: Column(
                            children: [
                              _buildCounterResponsive(
                                label: 'Preparation Time',
                                value: _prepTime,
                                unit: 'min',
                                onChanged: (v) => setState(() => _prepTime = v),
                              ),
                              _buildCounterResponsive(
                                label: 'Cooking Time',
                                value: _cookTime,
                                unit: 'min',
                                onChanged: (v) => setState(() => _cookTime = v),
                              ),
                              _buildCounterResponsive(
                                label: 'Serving',
                                value: _servings,
                                unit: '',
                                onChanged: (v) => setState(() => _servings = v),
                              ),
                                              // Difficulty Dropdown
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 29.sw, vertical: 8.sh),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Difficulty',
                                      style: TextStyle(
                                        color: purple,
                                        fontSize: 15.sp,
                                        fontFamily: 'Satoshi',
                                      ),
                                    ),
                                    Container(
                                      width: 176.sw,
                                      height: 61.sh,
                                      decoration: BoxDecoration(
                                        color: cardBg,
                                        borderRadius: BorderRadius.circular(20.sw),
                                      ),
                                      padding: EdgeInsets.symmetric(horizontal: 20.sw),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _difficulty,
                                          hint: Text(
                                            'Select',
                                            style: TextStyle(
                                              color: purple.withValues(alpha: 0.5),
                                              fontSize: 15.sp,
                                              fontFamily: 'Satoshi',
                                            ),
                                          ),
                                          icon: Icon(Icons.keyboard_arrow_down, color: purple, size: 24.sw),
                                          items: ['Easy', 'Medium', 'Hard'].map((String level) {
                                            return DropdownMenuItem<String>(
                                              value: level,
                                              child: Text(
                                                level,
                                                style: TextStyle(
                                                  color: purple,
                                                  fontSize: 15.sp,
                                                  fontFamily: 'Satoshi',
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (String? newValue) {
                                            setState(() {
                                              _difficulty = newValue;
                                            });
                                          },
                                          dropdownColor: cardBg,
                                          borderRadius: BorderRadius.circular(20.sw),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 20.sh),
                        SizedBox(height: 10.sh),
                        _StaggeredFadeIn(
                          delay: 2,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 29.sw),
                            child: Theme(
                              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                              child: Column(
                                children: _allCategories.entries.map((entry) {
                                  final categoryName = entry.key;
                                  final categoryTags = entry.value;
                                  final selectedInCategory = categoryTags.where((t) => _selectedTags.contains(t)).length;
                                  final icon = _getCategoryIcon(categoryName);

                                  return Container(
                                    margin: EdgeInsets.only(bottom: 12.sh),
                                    decoration: BoxDecoration(
                                      color: cardBg.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(20.sw),
                                      border: Border.all(color: cardBg),
                                    ),
                                    child: ExpansionTile(
                                      leading: Icon(icon, color: purple, size: 22.sw),
                                      title: Row(
                                        children: [
                                          Text(
                                            categoryName,
                                            style: TextStyle(
                                              color: purple,
                                              fontSize: 15.sp,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'Satoshi',
                                            ),
                                          ),
                                          if (selectedInCategory > 0) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: orange,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                selectedInCategory.toString(),
                                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      iconColor: purple,
                                      collapsedIconColor: purple.withValues(alpha: 0.6),
                                      children: [
                                        Padding(
                                          padding: EdgeInsets.fromLTRB(16.sw, 0, 16.sw, 16.sh),
                                          child: Wrap(
                                            spacing: 10.sw,
                                            runSpacing: 10.sh,
                                            children: categoryTags.map((tag) {
                                              final isSelected = _selectedTags.contains(tag);
                                              return GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    if (isSelected) {
                                                      _selectedTags.remove(tag);
                                                    } else {
                                                      _selectedTags.add(tag);
                                                    }
                                                  });
                                                },
                                                child: AnimatedContainer(
                                                  duration: const Duration(milliseconds: 200),
                                                  padding: EdgeInsets.symmetric(horizontal: 16.sw, vertical: 10.sh),
                                                  decoration: BoxDecoration(
                                                    color: isSelected ? purple : cardBg.withValues(alpha: 0.3),
                                                    borderRadius: BorderRadius.circular(30.sw),
                                                    border: Border.all(color: isSelected ? purple : purple.withValues(alpha: 0.1)),
                                                  ),
                                                  child: Text(
                                                    _beautify(tag),
                                                    style: TextStyle(
                                                      color: isSelected ? const Color(0xFFFFF2EA) : purple,
                                                      fontSize: 12.sp,
                                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                                      fontFamily: 'Satoshi',
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),

                        // Bottom buttons inside the scrollable area
                        Padding(
                          padding: EdgeInsets.fromLTRB(30.sw, 42.sh, 29.sw, 42.sh),
                          child: _StaggeredFadeIn(
                            delay: 3,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: _AnimatedNextButton(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => UploadRecipeStep3(
                                        title: widget.title,
                                        image: widget.image,
                                        prepTime: _prepTime,
                                        cookTime: _cookTime,
                                        servings: _servings,
                                        difficulty: _difficulty,
                                        tags: _selectedTags,
                                        editingRecipe: widget.editingRecipe,
                                      ),
                                    ),
                                  );
                                },
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

  Widget _buildCounterResponsive({
    required String label,
    required int value,
    required String unit,
    required Function(int) onChanged,
  }) {
    return _CounterInput(
      label: label,
      value: value,
      unit: unit,
      onChanged: onChanged,
      purple: purple,
      cardBg: cardBg,
      textBrown: textBrown,
    );
  }
}

class _CounterInput extends StatefulWidget {
  final String label;
  final int value;
  final String unit;
  final Function(int) onChanged;
  final Color purple;
  final Color cardBg;
  final Color textBrown;

  const _CounterInput({
    required this.label,
    required this.value,
    required this.unit,
    required this.onChanged,
    required this.purple,
    required this.cardBg,
    required this.textBrown,
  });

  @override
  State<_CounterInput> createState() => _CounterInputState();
}

class _CounterInputState extends State<_CounterInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
  }

  @override
  void didUpdateWidget(_CounterInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value.toString() != _controller.text) {
      _controller.text = widget.value.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 29.sw, vertical: 8.sh),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(widget.label,
                style: TextStyle(
                  color: widget.purple,
                  fontSize: 15.sp,
                  fontFamily: 'Satoshi',
                )),
          ),
          Container(
            width: 176.sw,
            height: 61.sh,
            decoration: BoxDecoration(
              color: widget.cardBg,
              borderRadius: BorderRadius.circular(8.sw),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () {
                    if (widget.value > 0) widget.onChanged(widget.value - 1);
                  },
                  child: Padding(
                    padding: EdgeInsets.all(8.0.sw),
                    child: Text('-',
                        style: TextStyle(
                          color: const Color(0xFF74503C),
                          fontSize: 24.sp,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Satoshi',
                        )),
                  ),
                ),
                SizedBox(
                  width: 50.sw,
                  child: TextField(
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final parsed = int.tryParse(v);
                      if (parsed != null) widget.onChanged(parsed);
                    },
                    controller: _controller,
                    decoration: const InputDecoration(border: InputBorder.none),
                    style: TextStyle(
                      color: widget.textBrown,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Satoshi',
                    ),
                  ),
                ),
                if (widget.unit.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(right: 8.sw),
                    child: Text(widget.unit,
                        style: TextStyle(
                          color: widget.textBrown,
                          fontSize: 12.sp,
                          fontFamily: 'Satoshi',
                        )),
                  ),
                GestureDetector(
                  onTap: () => widget.onChanged(widget.value + 1),
                  child: Padding(
                    padding: EdgeInsets.all(8.0.sw),
                    child: Text('+',
                        style: TextStyle(
                          color: const Color(0xFF74503C),
                          fontSize: 24.sp,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Satoshi',
                        )),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StaggeredFadeIn extends StatelessWidget {
  final Widget child;
  final int delay;
  const _StaggeredFadeIn({required this.child, this.delay = 0});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 600 + (delay * 100)),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
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

 


