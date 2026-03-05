import 'package:flutter/material.dart';

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
  final Color cardBg = const Color(0xFFF9E3D5); // Updated card background
  final Color unactivatedBg = const Color(0xFFFFF2EA); // Updated unactivated tag color
  final Color selectedBg = const Color(0xFF462F4D); // Purple
  final Color selectedText = Colors.white;
  final Color unselectedText = const Color(0xFF462F4D);
  final Color orange = const Color(0xFFEF8A54);

  int? _maxMinutes;
  final Set<String> _selectedTags = {};

  final List<String> _dietTags = [
    "Vegetarian",
    "Vegan",
    "Halal",
    "Kosher",
    "Heart Healthy",
    "Gluten-Free",
    "Dairy-Free",
    "Keto",
    "Paleo",
    "Low-Carb",
    "Low-Fat",
    "Sugar-Free",
  ];

  final List<String> _cuisineTags = [
    "Italian",
    "Chinese",
    "Mexican",
    "Indian",
    "Japanese",
    "Thai",
    "Mediterranean",
    "American",
    "French",
    "Korean",
  ];

  final List<String> _mealTypes = [
    "Breakfast",
    "Lunch",
    "Dinner",
    "Snack",
    "Dessert",
    "Appetizer",
  ];

  @override
  void initState() {
    super.initState();
    _maxMinutes = widget.initialMaxMinutes;
    _selectedTags.addAll(widget.initialSelectedTags);
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  void _toggleTime(int minutes) {
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
    return Container(
      decoration: BoxDecoration(
        color: cardBg, // Updated to F9E3D5
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.50, // Max 50% of screen
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 20),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: orange,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection("Time", [
                    _buildTimeChip("Under 15 Minutes", 15),
                    _buildTimeChip("Under 30 Minutes", 30),
                    _buildTimeChip("Under 1 Hour", 60),
                  ]),

                  const SizedBox(height: 24),

                  _buildSection("Diet", _dietTags.map((t) => _buildTagChip(t)).toList()),

                  const SizedBox(height: 24),

                  _buildSection("Cuisine", _cuisineTags.map((t) => _buildTagChip(t)).toList()),

                  const SizedBox(height: 24),

                  _buildSection("Meal Type", _mealTypes.map((t) => _buildTagChip(t)).toList()),

                  const SizedBox(height: 32),

                  // Apply Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onApply(_maxMinutes, _selectedTags.toList());
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        "Apply Filters",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: "Satoshi",
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
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: "Satoshi",
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: chips,
        ),
      ],
    );
  }

  Widget _buildTimeChip(String label, int minutes) {
    final isSelected = _maxMinutes == minutes;
    return GestureDetector(
      onTap: () => _toggleTime(minutes),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : unactivatedBg, // Updated unactivated color
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? selectedText : unselectedText,
            fontSize: 14,
            fontWeight: FontWeight.w600,
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : unactivatedBg, // Updated unactivated color
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          tag,
          style: TextStyle(
            color: isSelected ? selectedText : unselectedText,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: "Satoshi",
          ),
        ),
      ),
    );
  }
}
