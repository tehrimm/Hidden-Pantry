import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'upload_recipe_step3.dart';

class UploadRecipeStep2 extends StatefulWidget {
  final String title;
  final File? image;

  const UploadRecipeStep2({
    super.key,
    required this.title,
    this.image,
  });

  @override
  State<UploadRecipeStep2> createState() => _UploadRecipeStep2State();
}

class _UploadRecipeStep2State extends State<UploadRecipeStep2> {
  int _prepTime = 15;
  int _cookTime = 40;
  int _servings = 2;
  String? _difficulty;
  final List<String> _selectedTags = [];

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
                        SizedBox(width: 40 * s), // Spacer for centering title
                        Text(
                          'Add Recipe',
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
                      padding: EdgeInsets.only(top: 20 * s, bottom: 20 * s),
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
                                height: 60 * s,
                                padding: EdgeInsets.symmetric(horizontal: 12 * s),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(8 * s),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _difficulty,
                                    hint: Text(
                                      'Select Status',
                                      style: TextStyle(
                                        color: textBrown,
                                        fontSize: 12 * s,
                                        fontFamily: 'Satoshi',
                                      ),
                                    ),
                                    icon: Icon(Icons.keyboard_arrow_down, size: 20 * s),
                                    items: ['Easy', 'Medium', 'Difficult'].map((String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(
                                          value,
                                          style: TextStyle(
                                            color: textBrown,
                                            fontSize: 12 * s,
                                            fontFamily: 'Satoshi',
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (v) {
                                      setState(() => _difficulty = v);
                                    },
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

                        // Bottom buttons moved inside the scrollable area to avoid keyboard overlap
                        Padding(
                          padding: EdgeInsets.fromLTRB(30 * s, 42 * s, 29 * s, 42 * s),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  width: 52 * s,
                                  height: 53 * s,
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(15 * s),
                                  ),
                                  child: Icon(Icons.arrow_back_ios_new, size: 16 * s, color: const Color(0xFF462F4D)),
                                ),
                              ),
                              SizedBox(width: 60 * s),
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
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    height: 62 * s,
                                    decoration: BoxDecoration(
                                      color: orange,
                                      borderRadius: BorderRadius.circular(20 * s),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Next',
                                          style: TextStyle(
                                            color: const Color(0xFFFFF2EA),
                                            fontSize: 15 * s,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Satoshi',
                                          ),
                                        ),
                                        SizedBox(width: 10 * s),
                                        Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16 * s),
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
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 29 * scale, vertical: 8 * scale),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                  color: purple,
                  fontSize: 15 * scale,
                  fontFamily: 'Satoshi',
                )),
          ),
          Container(
            width: 176 * scale,
            height: 61 * scale,
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(8 * scale),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () {
                    if (value > 0) onChanged(value - 1);
                  },
                  child: Padding(
                    padding: EdgeInsets.all(8.0 * scale),
                    child: Text('-',
                        style: TextStyle(
                          color: const Color(0xFF74503C),
                          fontSize: 24 * scale,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Satoshi',
                        )),
                  ),
                ),
                SizedBox(
                  width: 50 * scale,
                  child: TextField(
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final parsed = int.tryParse(v);
                      if (parsed != null) onChanged(parsed);
                    },
                    controller: TextEditingValue(
                      text: value.toString(),
                      selection: TextSelection.collapsed(offset: value.toString().length),
                    ).let((v) => TextEditingController.fromValue(v)),
                    decoration: const InputDecoration(border: InputBorder.none),
                    style: TextStyle(
                      color: textBrown,
                      fontSize: 16 * scale,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Satoshi',
                    ),
                  ),
                ),
                if (unit.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(right: 8 * scale),
                    child: Text(unit,
                        style: TextStyle(
                          color: textBrown,
                          fontSize: 12 * scale,
                          fontFamily: 'Satoshi',
                        )),
                  ),
                GestureDetector(
                  onTap: () => onChanged(value + 1),
                  child: Padding(
                    padding: EdgeInsets.all(8.0 * scale),
                    child: Text('+',
                        style: TextStyle(
                          color: const Color(0xFF74503C),
                          fontSize: 24 * scale,
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



