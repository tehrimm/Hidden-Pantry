import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
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
  final Color orange = const Color(0xFFF2894F);
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

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3EB),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final s = constraints.maxWidth / 393;

          return Stack(
            children: [
              // Background Patterns
              _BackgroundPatterns(scale: s),

              Column(
                children: [
                  SizedBox(height: 50 * s),
                  // Fixed Header area
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 29 * s),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        BackButtonWidget(color: purple),
                        Text(
                          widget.editingRecipe != null ? 'Edit Recipe' : 'Add Recipe',
                          style: TextStyle(
                            color: purple,
                            fontSize: 20 * s,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Satoshi',
                          ),
                        ),
                        // Step Indicator
                        Container(
                          width: 69 * s,
                          height: 42 * s,
                          decoration: BoxDecoration(
                            color: purple,
                            borderRadius: BorderRadius.circular(10 * s),
                          ),
                          child: Center(
                            child: Text(
                              '2/5',
                              style: TextStyle(
                                color: const Color(0xFFFFF2EA),
                                fontSize: 12 * s,
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
                      padding: EdgeInsets.only(top: 20 * s, bottom: 120),
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 27 * s),
                          child: Text(
                            'Information',
                            style: TextStyle(
                              color: purple,
                              fontSize: 40 * s,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                              fontFamily: 'Satoshi',
                            ),
                          ),
                        ),
                        SizedBox(height: 30 * s),

                        _buildCounterResponsive(
                          label: 'Preparation Time',
                          value: _prepTime,
                          unit: 'min',
                          scale: s,
                          onChanged: (v) => setState(() => _prepTime = v),
                        ),
                        _buildCounterResponsive(
                          label: 'Cooking Time',
                          value: _cookTime,
                          unit: 'min',
                          scale: s,
                          onChanged: (v) => setState(() => _cookTime = v),
                        ),
                        _buildCounterResponsive(
                          label: 'Serving',
                          value: _servings,
                          unit: '',
                          scale: s,
                          onChanged: (v) => setState(() => _servings = v),
                        ),

                        // Difficulty Dropdown
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 29 * s, vertical: 8 * s),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Difficulty',
                                style: TextStyle(
                                  color: purple,
                                  fontSize: 15 * s,
                                  fontFamily: 'Satoshi',
                                ),
                              ),
                              Container(
                                width: 176 * s,
                                height: 61 * s,
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(20 * s),
                                ),
                                padding: EdgeInsets.symmetric(horizontal: 20 * s),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _difficulty,
                                    hint: Text(
                                      'Select',
                                      style: TextStyle(
                                        color: purple.withValues(alpha: 0.5),
                                        fontSize: 15 * s,
                                        fontFamily: 'Satoshi',
                                      ),
                                    ),
                                    icon: Icon(Icons.keyboard_arrow_down, color: purple, size: 24 * s),
                                    items: ['Easy', 'Medium', 'Hard'].map((String level) {
                                      return DropdownMenuItem<String>(
                                        value: level,
                                        child: Text(
                                          level,
                                          style: TextStyle(
                                            color: purple,
                                            fontSize: 15 * s,
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
                                    borderRadius: BorderRadius.circular(20 * s),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 20 * s),
                        // All Categorized Tags
                        ..._allCategories.entries.map((entry) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(left: 29 * s, top: 16 * s, bottom: 8 * s),
                                child: Text(
                                  entry.key,
                                  style: TextStyle(
                                    color: purple,
                                    fontSize: 15 * s,
                                    fontFamily: 'Satoshi',
                                  ),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 29 * s),
                                child: Wrap(
                                  spacing: 10 * s,
                                  runSpacing: 10 * s,
                                  children: entry.value.map((tag) {
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
                                      child: Container(
                                        padding: EdgeInsets.symmetric(horizontal: 16 * s, vertical: 10 * s),
                                        decoration: BoxDecoration(
                                          color: isSelected ? purple : cardBg,
                                          borderRadius: BorderRadius.circular(30 * s),
                                        ),
                                        child: Text(
                                          _beautify(tag),
                                          style: TextStyle(
                                            color: isSelected ? const Color(0xFFFFF2EA) : purple,
                                            fontSize: 12 * s,
                                            fontWeight: FontWeight.w500,
                                            fontFamily: 'Satoshi',
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          );
                        }).toList(),

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
          );
        },
      ),
    );
  }

  Widget _buildCounterResponsive({
    required String label,
    required int value,
    required String unit,
    required double scale,
    required Function(int) onChanged,
  }) {
    return _CounterInput(
      label: label,
      value: value,
      unit: unit,
      scale: scale,
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
  final double scale;
  final Function(int) onChanged;
  final Color purple;
  final Color cardBg;
  final Color textBrown;

  const _CounterInput({
    required this.label,
    required this.value,
    required this.unit,
    required this.scale,
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
      padding: EdgeInsets.symmetric(horizontal: 29 * widget.scale, vertical: 8 * widget.scale),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(widget.label,
                style: TextStyle(
                  color: widget.purple,
                  fontSize: 15 * widget.scale,
                  fontFamily: 'Satoshi',
                )),
          ),
          Container(
            width: 176 * widget.scale,
            height: 61 * widget.scale,
            decoration: BoxDecoration(
              color: widget.cardBg,
              borderRadius: BorderRadius.circular(8 * widget.scale),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () {
                    if (widget.value > 0) widget.onChanged(widget.value - 1);
                  },
                  child: Padding(
                    padding: EdgeInsets.all(8.0 * widget.scale),
                    child: Text('-',
                        style: TextStyle(
                          color: const Color(0xFF74503C),
                          fontSize: 24 * widget.scale,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Satoshi',
                        )),
                  ),
                ),
                SizedBox(
                  width: 50 * widget.scale,
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
                      fontSize: 16 * widget.scale,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Satoshi',
                    ),
                  ),
                ),
                if (widget.unit.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(right: 8 * widget.scale),
                    child: Text(widget.unit,
                        style: TextStyle(
                          color: widget.textBrown,
                          fontSize: 12 * widget.scale,
                          fontFamily: 'Satoshi',
                        )),
                  ),
                GestureDetector(
                  onTap: () => widget.onChanged(widget.value + 1),
                  child: Padding(
                    padding: EdgeInsets.all(8.0 * widget.scale),
                    child: Text('+',
                        style: TextStyle(
                          color: const Color(0xFF74503C),
                          fontSize: 24 * widget.scale,
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

class _BackgroundPatterns extends StatelessWidget {
  final double scale;
  const _BackgroundPatterns({required this.scale});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: -154 * scale,
            top: -14 * scale,
            child: Transform.rotate(
              angle: 21 * math.pi / 180,
              child: Container(
                width: 271 * scale,
                height: 159 * scale,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFF5DDCE)),
                  borderRadius: BorderRadius.all(Radius.elliptical(136 * scale, 80 * scale)),
                ),
              ),
            ),
          ),
          Positioned(
            left: -149 * scale,
            top: -100 * scale,
            child: Transform.rotate(
              angle: 4 * math.pi / 180,
              child: Container(
                width: 303 * scale,
                height: 329 * scale,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFF5DDCE)),
                  borderRadius: BorderRadius.all(Radius.elliptical(152 * scale, 165 * scale)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension on TextEditingValue {
  T let<T>(T Function(TextEditingValue) block) => block(this);
}


