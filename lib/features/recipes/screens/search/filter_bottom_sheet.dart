import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';

class FilterBottomSheet extends StatefulWidget {
  final int? initialMaxMinutes;
  final List<String> initialSelectedTags;
  final Function(int? maxMinutes, List<String> tags) onApply;

  const FilterBottomSheet({
    super.key,
    required this.initialMaxMinutes,
    required this.initialSelectedTags,
    required this.onApply,
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  final Color primary = const Color(0xFF462F4D);
  final Color bg = const Color(0xFFFFF3EB);
  final Color orange = const Color(0xFFEF8A54);

  int? _maxMinutes;
  final Set<String> _selectedTags = {};

  final List<String> _dietTags = [
    "Vegetarian",
    "Vegan",
    "Low Carb",
    "High Protein",
    "High Fiber",
    "Diabetic-Friendly",
    "Low Sodium",
  ];

  final List<String> _cuisineTags = [
    "Italian",
    "Mexican",
    "Chinese",
    "Indian",
    "Japanese",
    "Thai",
    "Mediterranean",
    "American",
    "French",
    "Korean",
    "Amish & Mennonite",
  ];

  final List<String> _mealTypes = [
    "Breakfast",
    "Brunch",
    "Lunch",
    "Dinner",
    "Snack",
    "Dessert",
    "Appetizer",
  ];

  final List<String> _methodTags = [
    "No Bake",
    "Pressure Cooker",
    "Deep Fried",
    "Stir-Fry",
    "Steaming",
    "Broil/Grill",
    "Make-Ahead",
  ];

  final List<String> _flavorTags = [
    "Spicy & Hot",
    "Creamy & Cheesy",
    "Crunchy & Crispy",
    "Tangy & Sour",
    "Gooey",
    "Smoky",
  ];

  final List<String> _themeTags = [
    "5 Ingredients or Less",
    "One-Pot/One-Dish",
    "Freezer-Friendly",
    "Kids Can Make",
    "Tailgate & Game Day",
    "Thanksgiving/Christmas",
  ];

  @override
  void initState() {
    super.initState();
    _maxMinutes = widget.initialMaxMinutes;
    _selectedTags.addAll(widget.initialSelectedTags);
  }

  void _toggleTag(String tag) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  void _toggleTime(int minutes) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_maxMinutes == minutes) {
        _maxMinutes = null;
      } else {
        _maxMinutes = minutes;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32.sw)),
        boxShadow: [
          BoxShadow(color: primary.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, -5))
        ],
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85, 
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Padding(
            padding: EdgeInsets.only(top: 12.sh, bottom: 24.sh),
            child: Container(
              width: 48.sw,
              height: 5.sh,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3.sw),
              ),
            ),
          ),
          
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24.sw, 0, 24.sw, 40.sh),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FadeSlideEntry(
                    delayMs: 100,
                    child: _buildSection("Time", [
                      _buildTimeChip("Under 15 Minutes", 15),
                      _buildTimeChip("Under 30 Minutes", 30),
                      _buildTimeChip("Under 1 Hour", 60),
                    ]),
                  ),
                  SizedBox(height: 32.sh),

                  _FadeSlideEntry(
                    delayMs: 200,
                    child: _buildSection("Diet", _dietTags.map((t) => _buildTagChip(t)).toList()),
                  ),
                  SizedBox(height: 32.sh),

                  _FadeSlideEntry(
                    delayMs: 300,
                    child: _buildSection("Meal Type", _mealTypes.map((t) => _buildTagChip(t)).toList()),
                  ),
                  SizedBox(height: 32.sh),

                  _FadeSlideEntry(
                    delayMs: 400,
                    child: _buildSection("Cuisine", _cuisineTags.map((t) => _buildTagChip(t)).toList()),
                  ),
                  SizedBox(height: 32.sh),

                  _FadeSlideEntry(
                    delayMs: 500,
                    child: _buildSection("Cooking Method", _methodTags.map((t) => _buildTagChip(t)).toList()),
                  ),
                  SizedBox(height: 32.sh),

                  _FadeSlideEntry(
                    delayMs: 600,
                    child: _buildSection("Flavor & Texture", _flavorTags.map((t) => _buildTagChip(t)).toList()),
                  ),
                  SizedBox(height: 32.sh),

                  _FadeSlideEntry(
                    delayMs: 700,
                    child: _buildSection("Occasion & Theme", _themeTags.map((t) => _buildTagChip(t)).toList()),
                  ),
                  SizedBox(height: 48.sh),

                  _FadeSlideEntry(
                    delayMs: 500,
                    child: SizedBox(
                      width: double.infinity,
                      height: 56.sh,
                      child: ElevatedButton(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          Navigator.pop(context);
                          widget.onApply(_maxMinutes, _selectedTags.toList());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: orange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.sw),
                          ),
                          elevation: 8,
                          shadowColor: orange.withValues(alpha: 0.4),
                        ),
                        child: Text(
                          "Apply Filters",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            fontFamily: "Satoshi",
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> chips) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: primary,
            fontSize: 20.sp,
            fontWeight: FontWeight.w900,
            fontFamily: "Satoshi",
          ),
        ),
        SizedBox(height: 16.sh),
        Wrap(
          spacing: 12.sw,
          runSpacing: 12.sh,
          children: chips,
        ),
      ],
    );
  }

  Widget _buildTimeChip(String label, int minutes) {
    final isSelected = _maxMinutes == minutes;
    return GestureDetector(
      onTap: () => _toggleTime(minutes),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 20.sw, vertical: 12.sh),
        decoration: BoxDecoration(
          color: isSelected ? primary : Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(24.sw),
          border: Border.all(color: isSelected ? primary : Colors.white, width: 1.5),
          boxShadow: isSelected 
             ? [BoxShadow(color: primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))]
             : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 3))],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : primary,
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
            fontFamily: "Satoshi",
          ),
        ),
      ),
    );
  }

  Widget _buildTagChip(String tag) {
    final isSelected = _selectedTags.contains(tag);
    return GestureDetector(
      onTap: () => _toggleTag(tag),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 20.sw, vertical: 12.sh),
        decoration: BoxDecoration(
          color: isSelected ? primary : Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(24.sw),
          border: Border.all(color: isSelected ? primary : Colors.white, width: 1.5),
          boxShadow: isSelected 
             ? [BoxShadow(color: primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))]
             : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 3))],
        ),
        child: Text(
          tag,
          style: TextStyle(
            color: isSelected ? Colors.white : primary,
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
            fontFamily: "Satoshi",
          ),
        ),
      ),
    );
  }
}

class _FadeSlideEntry extends StatefulWidget {
  final Widget child;
  final int delayMs;
  const _FadeSlideEntry({required this.child, this.delayMs = 0});
  @override
  State<_FadeSlideEntry> createState() => _FadeSlideEntryState();
}

class _FadeSlideEntryState extends State<_FadeSlideEntry> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child));
  }
}
