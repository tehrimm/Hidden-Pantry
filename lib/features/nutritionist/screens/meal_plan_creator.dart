import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/core/utils/glass_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_api_service.dart';
import 'package:hidden_pantry_app/core/constants/api_constants.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';


class MealPlanCreatorScreen extends StatefulWidget {
  final String? existingPlanId;
  final Map<String, dynamic>? initialData;

  const MealPlanCreatorScreen({super.key, this.existingPlanId, this.initialData});

  @override
  State<MealPlanCreatorScreen> createState() => _MealPlanCreatorScreenState();
}

class _MealPlanCreatorScreenState extends State<MealPlanCreatorScreen> {
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _caloriesCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  
  int _durationDays = 7;
  int _selectedDay = 1;

  final Color purple = const Color(0xFF462F4D);
  final Color orange = const Color(0xFFEF8A54);

  // Map of dayIndex -> List of Meals
  Map<int, List<Map<String, dynamic>>> _dayMeals = {};

  final RecipeApiService _apiService = const RecipeApiService(baseUrl: ApiConstants.baseUrl);

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      final data = widget.initialData!;
      _titleCtrl.text = data['title'] ?? '';
      _caloriesCtrl.text = data['targetCalories']?.toString() ?? '';
      _notesCtrl.text = data['notes'] ?? '';
      _durationDays = data['duration'] ?? 7;
      
      final daysData = data['days'] as List<dynamic>? ?? [];
      for (var dayDoc in daysData) {
        final dayNum = dayDoc['day'] as int;
        final mealsDynamic = dayDoc['meals'] as List<dynamic>? ?? [];
        _dayMeals[dayNum] = mealsDynamic.map((m) => Map<String, dynamic>.from(m)).toList();
      }
      
      // Initialize any missing days up to _durationDays
      for (int i = 1; i <= _durationDays; i++) {
        if (!_dayMeals.containsKey(i)) {
          _dayMeals[i] = [];
        }
      }
    } else {
      for (int i = 1; i <= _durationDays; i++) {
        _dayMeals[i] = [];
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F2),
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        title: Text(
          widget.existingPlanId == null ? "Create Meal Plan" : "Edit Meal Plan",
          style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontFamily: "Satoshi"),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
             margin: EdgeInsets.all(8.sw),
             alignment: Alignment.center,
             child: Icon(Icons.arrow_back_rounded, color: purple, size: 24.sw),
          ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16.sw),
            child: TextButton(
              onPressed: _savePlan,
              style: TextButton.styleFrom(
                backgroundColor: orange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.sw)),
                padding: EdgeInsets.symmetric(horizontal: 20.sw, vertical: 8.sh),
              ),
              child: Text("Save", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.sp)),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          const PatternBackground(),
          SingleChildScrollView(
            padding: EdgeInsets.all(22.sw),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: kToolbarHeight + MediaQuery.of(context).padding.top),
                _buildHeaderSection(),
                SizedBox(height: 24.sh),
                _buildDurationSelector(),
                SizedBox(height: 24.sh),
                _buildDaySelector(),
                SizedBox(height: 24.sh),
                _buildMealListForDay(_selectedDay),
                SizedBox(height: 24.sh),
                _buildNotesSection(),
                SizedBox(height: 100.sh), 
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return _FadeSlideEntry(
      delayMs: 100,
      child: Container(
        padding: EdgeInsets.all(20.sw),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(24.sw),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 6)),
          ],
        ),
        child: TextField(
          controller: _titleCtrl,
          style: TextStyle(color: purple, fontSize: 18.sp, fontWeight: FontWeight.w900, fontFamily: "Satoshi", height: 1.1),
          decoration: InputDecoration(
            hintText: "Plan Title (e.g., Weight Loss Week 1)",
            hintStyle: TextStyle(color: purple.withValues(alpha:0.4), fontSize: 16.sp, fontWeight: FontWeight.normal),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }

  Widget _buildDurationSelector() {
    return _FadeSlideEntry(
      delayMs: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Text("Duration", style: TextStyle(color: purple, fontSize: 16.sp, fontWeight: FontWeight.bold)),
        SizedBox(height: 12.sh),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [1, 3, 5, 7, 14, 28].map((days) {
              final isSelected = _durationDays == days;
              return GestureDetector(
                onTap: () => setState(() => _durationDays = days),
                child: Container(
                  margin: EdgeInsets.only(right: 10.sw),
                  padding: EdgeInsets.symmetric(horizontal: 20.sw, vertical: 10.sh),
                  decoration: BoxDecoration(
                    color: isSelected ? purple : Colors.white,
                    borderRadius: BorderRadius.circular(20.sw),
                    border: Border.all(color: isSelected ? purple : purple.withValues(alpha:0.1)),
                    boxShadow: isSelected ? [BoxShadow(color: purple.withValues(alpha:0.3), blurRadius: 8.sw, offset: Offset(0, 4.sh))] : [],
                  ),
                  child: Text(
                    "$days Days",
                    style: TextStyle(
                      color: isSelected ? Colors.white : purple,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp,
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
  }

  Widget _buildDaySelector() {
    return _FadeSlideEntry(
      delayMs: 200,
      child: SizedBox(
        height: 80.sh,
        child: ListView.builder(
        key: const Key('day_selector_list'),
        scrollDirection: Axis.horizontal,
        itemCount: _durationDays,
        itemBuilder: (context, index) {
          final dayNum = index + 1;
          final isSelected = _selectedDay == dayNum;
          return GestureDetector(
            onTap: () => setState(() => _selectedDay = dayNum),
            child: Container(
              width: 60.sw,
              margin: EdgeInsets.only(right: 12.sw),
              decoration: BoxDecoration(
                color: isSelected ? orange : Colors.white,
                borderRadius: BorderRadius.circular(16.sw),
                border: Border.all(color: isSelected ? orange : purple.withValues(alpha:0.1)),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "DAY",
                      style: TextStyle(
                        color: isSelected ? Colors.white.withValues(alpha:0.8) : purple.withValues(alpha:0.4),
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "$dayNum",
                      style: TextStyle(
                        color: isSelected ? Colors.white : purple,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        ),
      ),
    );
  }

  Widget _buildMealListForDay(int day) {
    return Column(
      children: [
        _buildCategorySection("Breakfast", Icons.wb_sunny_rounded),
        SizedBox(height: 16.sh),
        _buildCategorySection("Lunch", Icons.lunch_dining_rounded),
        SizedBox(height: 16.sh),
        _buildCategorySection("Dinner", Icons.nights_stay_rounded),
        SizedBox(height: 16.sh),
        _buildCategorySection("Snacks", Icons.apple_rounded),
      ],
    );
  }

  Widget _buildCategorySection(String title, IconData icon) {
    final meals = _dayMeals[_selectedDay]?.where((m) => m["type"] == title).toList() ?? [];

    return _FadeSlideEntry(
      delayMs: 300,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20.sw),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 6))],
        ),
        padding: EdgeInsets.all(16.sw),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: orange, size: 20.sw),
              SizedBox(width: 8.sw),
              Text(title, style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 16.sp)),
            ],
          ),
          Divider(height: 24.sh),
          if (meals.isEmpty)
            Text("No meals added", style: TextStyle(color: purple.withValues(alpha:0.4), fontSize: 13.sp, fontStyle: FontStyle.italic)),
          ...meals.map((m) {
            if (m["isNote"] == true) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.sticky_note_2_outlined, color: purple.withValues(alpha:0.4), size: 24.sw),
                title: Text(m["note"], style: TextStyle(color: purple, fontStyle: FontStyle.italic, fontSize: 14.sp)),
                trailing: IconButton(
                  icon: Icon(Icons.close, size: 18.sw, color: purple.withValues(alpha:0.4)),
                  onPressed: () {
                    setState(() {
                      _dayMeals[_selectedDay]?.removeWhere((element) => 
                          element["isNote"] == true && 
                          element["note"] == m["note"] && 
                          element["type"] == m["type"]);
                    });
                  },
                ),
              );
            }
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(m["title"] ?? m["name"] ?? "Recipe", style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 14.sp)),
              subtitle: Text("${m["calories"]} kcal", style: TextStyle(color: purple.withValues(alpha:0.6), fontSize: 12.sp)),
              trailing: IconButton(
                icon: Icon(Icons.close, size: 18.sw, color: purple.withValues(alpha:0.4)),
                onPressed: () {
                  setState(() {
                    _dayMeals[_selectedDay]?.removeWhere((element) => 
                        (element["recipeId"] == m["recipeId"] || element["id"] == m["id"] || element["id"] == m["recipeId"]) &&
                        element["type"] == m["type"]);
                  });
                },
              ),
            );
          }).toList(),
          SizedBox(height: 12.sh),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _addMealButton(title),
              SizedBox(width: 8.sw),
              _addNoteButton(title),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _addNoteButton(String type) {
    return TextButton.icon(
      onPressed: () => _showAddNoteDialog(type),
      icon: Icon(Icons.note_add_outlined, color: purple, size: 18.sw),
      label: Text("Add Note", style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 13.sp)),
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 16.sw, vertical: 8.sh),
        backgroundColor: purple.withValues(alpha:0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.sw)),
      ),
    );
  }

  void _showAddNoteDialog(String type) {
    final TextEditingController noteCtrl = TextEditingController();
    GlassDialog.show(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFF7F2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.sw)),
        title: Text("Add Note to $type", style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 18.sp, fontFamily: "Satoshi")),
        content: TextField(
          controller: noteCtrl,
          maxLines: 3,
          style: TextStyle(fontSize: 14.sp, color: purple),
          decoration: InputDecoration(
            hintText: "Enter your note here...",
            hintStyle: TextStyle(fontSize: 14.sp, color: purple.withValues(alpha: 0.4)),
            filled: true,
            fillColor: const Color(0xFFF9E3D5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.sw), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: purple.withValues(alpha:0.6))),
          ),
          ElevatedButton(
            onPressed: () {
              if (noteCtrl.text.trim().isNotEmpty) {
                setState(() {
                  _dayMeals[_selectedDay]?.add({
                    "type": type,
                    "isNote": true,
                    "note": noteCtrl.text.trim(),
                  });
                });
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.sw)),
            ),
            child: Text("Add", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.sp)),
          ),
        ],
      ),
    );
  }

  Widget _addMealButton(String type) {
    return Center(
      child: TextButton.icon(
        onPressed: () => _showRecipeSearch(type),
        icon: Icon(Icons.add_circle_outline_rounded, color: orange, size: 18),
        label: Text("Add Recipe", style: TextStyle(color: orange, fontWeight: FontWeight.bold)),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          backgroundColor: orange.withValues(alpha:0.1),

          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return _FadeSlideEntry(
      delayMs: 400,
      child: Container(
        padding: EdgeInsets.all(20.sw),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(24.sw),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Nutritionist's Note", style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 16.sp)),
            SizedBox(height: 12.sh),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            style: TextStyle(fontSize: 14.sp),
            decoration: InputDecoration(
              hintText: "Add any checks, instructions, or notes...",
              hintStyle: TextStyle(color: purple.withValues(alpha:0.4), fontSize: 14.sp),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.sw), borderSide: BorderSide(color: purple.withValues(alpha:0.1))),

              filled: true,
              fillColor: const Color(0xFFFDECE4).withValues(alpha:0.3),
            ),
          ),
        ],
      ),
      ),
    );
  }

  void _showRecipeSearch(String type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RecipeSearchModal(
        apiService: _apiService,
        onSelect: (recipe) {
          setState(() {
            final calorieString = recipe.nutrition?["Calories"]?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '0';
            final calories = int.tryParse(calorieString) ?? 0;
            
            _dayMeals[_selectedDay]?.add({
              "type": type,
              "recipeId": recipe.id,
              "title": recipe.name,
              "calories": calories,
              "imageUrl": recipe.imageUrl,
            });
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _savePlan() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_titleCtrl.text.isEmpty) {
      Toaster.show(context, "Please enter a title", isError: true);
      return;
    }

    try {
      // Calculate average calories per day
      int totalCalories = 0;
      for (var dayMeals in _dayMeals.values) {
        for (var meal in dayMeals) {
          if (meal["isNote"] != true) {
            totalCalories += (meal["calories"] as num?)?.toInt() ?? 0;
          }
        }
      }
      final computedTargetCalories = _durationDays > 0 ? (totalCalories / _durationDays).round() : 0;

      final planData = {
        "title": _titleCtrl.text.trim(),
        "duration": _durationDays,
        "targetCalories": computedTargetCalories, // Save dynamically computed avg
        "notes": _notesCtrl.text.trim(),
        "updatedAt": FieldValue.serverTimestamp(),
        "days": _dayMeals.entries.map((e) => {
          "day": e.key,
          "meals": e.value,
        }).toList(),
      };

      final colRef = FirebaseFirestore.instance
          .collection("nutritionists")
          .doc(user.uid)
          .collection("meal_plans");

      if (widget.existingPlanId != null) {
        await colRef.doc(widget.existingPlanId).update(planData);
      } else {
        await colRef.add({
          ...planData,
          "createdAt": FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        Navigator.pop(context);
        Toaster.show(context, "Meal Plan Saved!");
      }
    } catch (e) {
      if (mounted) {
        Toaster.show(context, "Error saving plan: $e", isError: true);
      }
    } finally {
      
    }
  }
}

class _RecipeSearchModal extends StatefulWidget {
  final RecipeApiService apiService;
  final Function(Recipe) onSelect;

  const _RecipeSearchModal({required this.apiService, required this.onSelect});

  @override
  State<_RecipeSearchModal> createState() => _RecipeSearchModalState();
}

class _RecipeSearchModalState extends State<_RecipeSearchModal> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Recipe> _results = [];
  bool _loading = false;
  Timer? _debounce;
  final Color purple = const Color(0xFF462F4D);
  final Color orange = const Color(0xFFEF8A54);

  List<String> _tags = [
    "Keto",
    "Low Fat",
    "High Protein",
    "Vegan",
    "Vegetarian",
    "Gluten-Free",
    "Low Carb",
    "Paleo"
  ];
  String? _selectedTag;

  @override
  void initState() {
    super.initState();
    // Use hardcoded health-related tags instead of fetching all tags
  }

  void _performSearch() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty && (_selectedTag == null || _selectedTag == "All")) {
      if (mounted) setState(() => _results = []);
      return;
    }
    if (mounted) setState(() => _loading = true);
    try {
      final res = await widget.apiService.searchRecipes(
        query,
        tags: _selectedTag != null && _selectedTag != "All" ? [_selectedTag!] : null,
      );
      if (mounted) setState(() => _results = res);
    } catch (e) {
      print("Search error: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _search(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _performSearch);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F2),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.sw)),
      ),
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.only(top: 12.sh, bottom: 20.sh),
            width: 50.sw, height: 5.sh,
            decoration: BoxDecoration(color: orange, borderRadius: BorderRadius.circular(10.sw)),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.sw),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: _search,
              style: TextStyle(fontSize: 16.sp),
              decoration: InputDecoration(
                hintText: "Search recipes...",
                hintStyle: TextStyle(fontSize: 16.sp),
                prefixIcon: Icon(Icons.search, color: purple.withValues(alpha:0.5), size: 24.sw),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.sw), borderSide: BorderSide.none),
                contentPadding: EdgeInsets.symmetric(horizontal: 16.sw, vertical: 14.sh),
              ),
            ),
          ),
          SizedBox(height: 10.sh),
          if (_tags.isNotEmpty)
            Container(
              height: 40.sh,
              margin: EdgeInsets.only(bottom: 10.sh),
              child: ListView.separated(
                padding: EdgeInsets.symmetric(horizontal: 20.sw),
                scrollDirection: Axis.horizontal,
                itemCount: _tags.length,
                separatorBuilder: (_, __) => SizedBox(width: 8.sw),
                itemBuilder: (context, index) {
                  final tag = _tags[index];
                  final isSelected = _selectedTag == tag;
                  return ChoiceChip(
                    label: Text(tag),
                    selected: isSelected,
                    selectedColor: orange,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : purple,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    backgroundColor: Colors.white,
                    side: BorderSide(color: isSelected ? orange : purple.withValues(alpha:0.1)),
                    onSelected: (val) {
                      setState(() {
                        _selectedTag = val ? tag : null;
                      });
                      _performSearch();
                    },
                  );
                },
              ),
            ),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: orange))
                : _results.isEmpty
                    ? Center(child: Text("Type to search recipes", style: TextStyle(color: purple.withValues(alpha:0.5))))
                    : ListView.separated(
                        padding: EdgeInsets.all(20.sw),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => SizedBox(height: 12.sh),
                        itemBuilder: (context, index) {
                          final recipe = _results[index];
                          final cal = recipe.nutrition?["Calories"] ?? "N/A";
                          return GestureDetector(
                            onTap: () => widget.onSelect(recipe),
                            child: Container(
                              padding: EdgeInsets.all(12.sw),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16.sw),
                                boxShadow: [BoxShadow(color: purple.withValues(alpha:0.05), blurRadius: 4.sw, offset: Offset(0, 2.sh))],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 50.sw, height: 50.sh,
                                    decoration: BoxDecoration(
                                      color: orange.withValues(alpha:0.1),
                                      borderRadius: BorderRadius.circular(12.sw),
                                      image: recipe.imageUrl != null 
                                          ? DecorationImage(image: NetworkImage(recipe.imageUrl!), fit: BoxFit.cover)
                                          : null,
                                    ),
                                    child: recipe.imageUrl == null ? Icon(Icons.restaurant, color: orange, size: 24.sw) : null,
                                  ),
                                  SizedBox(width: 12.sw),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(recipe.name, style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 14.sp), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        Text("$cal kcal", style: TextStyle(color: purple.withValues(alpha:0.6), fontSize: 12.sp)),

                                      ],
                                    ),
                                  ),
                                  Icon(Icons.add_circle, color: orange, size: 24.sw),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
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
    _slide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    bool isTest = WidgetsBinding.instance.runtimeType.toString().contains('TestWidgetsFlutterBinding') ||
                  Platform.environment.containsKey('FLUTTER_TEST');
    if (isTest) {
      _ctrl.forward();
    } else {
      Future.delayed(Duration(milliseconds: widget.delayMs), () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}