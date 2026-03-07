import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart' as hidden_pantry_recipe;
import 'package:hidden_pantry_app/features/recipes/screens/recipe_details.dart' as hidden_pantry_recipe_details;
import 'package:hidden_pantry_app/features/recipes/services/recipe_api_service.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_service.dart';
import 'package:hidden_pantry_app/core/constants/api_constants.dart';

class MealPlanViewScreen extends StatefulWidget {
  final Map<String, dynamic> planData;
  final bool isViewingSavedPlan;
  final RecipeApiService? apiService;
  final RecipeService? recipeService;

  const MealPlanViewScreen({super.key, required this.planData, this.isViewingSavedPlan = false, this.apiService, this.recipeService});

  @override
  State<MealPlanViewScreen> createState() => _MealPlanViewScreenState();
}

class _MealPlanViewScreenState extends State<MealPlanViewScreen> {
  final Color bg = const Color(0xFFFFF3EB);
  final Color purple = const Color(0xFF462F4D);
  final Color brown = const Color(0xFF433020);
  final Color orange = const Color(0xFFEF8A54);
  final Color cardColor = const Color(0xFFF9E3D5);

  bool _isSaving = false;

  Future<void> _savePlan() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      final planId = widget.planData["planId"] ?? FirebaseFirestore.instance.collection("temp").doc().id;
      
      // Save entire plan data to user's saved_meal_plans subcollection
      final dataToSave = Map<String, dynamic>.from(widget.planData);
      dataToSave["savedAt"] = FieldValue.serverTimestamp();
      
      // if planId wasn't in the data, add it so we can reference it when removing
      dataToSave["planId"] = planId;

      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("saved_meal_plans")
          .doc(planId)
          .set(dataToSave, SetOptions(merge: true));

      if (mounted) {
        Toaster.show(context, "Plan saved successfully!");
      }
    } catch (e) {
      if (mounted) {
        Toaster.show(context, "Error saving plan: $e", isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _removePlan() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      final planId = widget.planData["planId"];
      if (planId != null) {
        await FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .collection("saved_meal_plans")
            .doc(planId)
            .delete();

        if (mounted) {
          Toaster.show(context, "Plan removed from your library");
          Navigator.pop(context); // Go back after removing
        }
      }
    } catch (e) {
      if (mounted) {
        Toaster.show(context, "Error removing plan: $e", isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  int _selectedDay = 1;

  Future<hidden_pantry_recipe.Recipe?> _fetchLiveRecipe(String? recipeId) async {
    if (recipeId == null || recipeId.isEmpty) return null;
    if (widget.recipeService != null) {
      final r = await widget.recipeService!.getRecipeById(recipeId);
      if (r != null) return r;
    }
    if (widget.apiService != null) {
      try {
        final r = await widget.apiService!.getRecipeById(recipeId);
        if (r != null) return r;
      } catch (_) {}
    }
    try {
      final r = await RecipeService().getRecipeById(recipeId);
      if (r != null) return r;
    } catch (_) {}
    try {
      final r = await const RecipeApiService(baseUrl: ApiConstants.baseUrl).getRecipeById(recipeId);
      if (r != null) return r;
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.planData["title"] ?? "Untitled Plan";
    final targetCalories = widget.planData["targetCalories"] ?? "0";
    final notes = widget.planData["notes"] ?? "";
    final duration = widget.planData["duration"] ?? 0;
    final List<dynamic> days = widget.planData["days"] ?? [];

    // Calculate average meals per day for stats
    int totalMeals = 0;
    for (var day in days) {
      totalMeals += ((day["meals"] as List?)?.length ?? 0);
    }
    final avgMeals = duration > 0 ? (totalMeals / duration).round() : 0;

    // Default hero image (healthy food bowl placeholder)
    final heroImage = "https://images.unsplash.com/photo-1490645935967-10de6ba17061?q=80&w=2053&auto=format&fit=crop";

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // Pattern background for the lower half
          const Positioned.fill(child: PatternBackground()),
          
          CustomScrollView(
            slivers: [
              // 1. Visual Hero Header
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                backgroundColor: bg,
                elevation: 0,
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: BackButtonWidget(color: purple),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Hero Image
                      Image.network(heroImage, fit: BoxFit.cover),
                      // Gradient Overlay for text readability
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha:0.3),
                              purple.withValues(alpha:0.8),
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                      // Overlaid Metadata
                      Positioned(
                        bottom: 24,
                        left: 24,
                        right: 24,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: orange,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                "NUTRITION PLAN",
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                fontFamily: "Satoshi",
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 2. High-Level Statistics (The Dashboard Row)
                      Row(
                        children: [
                          Expanded(child: _buildStatCard(Icons.calendar_month_rounded, "$duration", "Days")),
                          const SizedBox(width: 12),
                          Expanded(child: _buildStatCard(Icons.local_fire_department_rounded, "~$targetCalories", "kcal/day")),
                          const SizedBox(width: 12),
                          Expanded(child: _buildStatCard(Icons.restaurant_rounded, "$avgMeals", "Meals/day")),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // 3. Professional Guidance (Nutritionist's Note)
                      if (notes.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: orange.withValues(alpha:0.3)),
                            boxShadow: [
                              BoxShadow(color: purple.withValues(alpha:0.04), blurRadius: 10, offset: const Offset(0, 4))
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.format_quote_rounded, color: orange, size: 24),
                                  const SizedBox(width: 8),
                                  Text("Nutritionist's Note", style: TextStyle(color: purple, fontSize: 16, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(notes, style: TextStyle(color: purple.withValues(alpha:0.7), fontSize: 14, height: 1.5)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],

                      // 4. Interactive Timeline (Daily Schedule)
                      Text(
                        "Meal Schedule",
                        style: TextStyle(color: purple, fontSize: 22, fontWeight: FontWeight.w900, fontFamily: "Satoshi"),
                      ),
                      const SizedBox(height: 16),
                      
                      // Horizontal Stepper
                      SizedBox(
                        height: 50,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: duration,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final dayNum = index + 1;
                            final isSelected = _selectedDay == dayNum;
                            
                            return GestureDetector(
                              onTap: () => setState(() => _selectedDay = dayNum),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                decoration: BoxDecoration(
                                  color: isSelected ? purple : Colors.white,
                                  borderRadius: BorderRadius.circular(25),
                                  border: Border.all(color: isSelected ? purple : purple.withValues(alpha:0.1)),
                                  boxShadow: isSelected 
                                      ? [BoxShadow(color: purple.withValues(alpha:0.3), blurRadius: 8, offset: const Offset(0, 4))]
                                      : [],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "Day $dayNum",
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : purple,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Vertical Chronology for the Selected Day
                      _buildSelectedDayTimeline(days),
                      
                      const SizedBox(height: 120), // Bottom padding for floating CTA
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 6. Persistent Call-to-Action (CTA) Footer (Hidden for Nutritionists viewing their sent plans)
          if (!widget.isViewingSavedPlan)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                decoration: BoxDecoration(
                  color: bg,
                  boxShadow: [
                    BoxShadow(color: purple.withValues(alpha:0.08), blurRadius: 20, offset: const Offset(0, -5))
                  ],
                ),
                child: widget.isViewingSavedPlan // This nested check is technically true/false but wrapped in an if
                  ? ElevatedButton(
                      onPressed: _isSaving ? null : _removePlan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFF0F0),
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.red.withValues(alpha:0.3)),
                        ),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.red, strokeWidth: 3))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.bookmark_remove_rounded, color: Colors.red),
                                SizedBox(width: 12),
                                Text(
                                  "Remove from My Plans",
                                  style: TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: "Satoshi"),
                                ),
                              ],
                            ),
                    )
                  : ElevatedButton(
                      onPressed: _isSaving ? null : _savePlan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: orange,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        shadowColor: orange.withValues(alpha:0.4),
                      ),
                      child: _isSaving
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.bookmark_add_rounded, color: Colors.white),
                                SizedBox(width: 12),
                                Text(
                                  "Save to My Plans",
                                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: "Satoshi"),
                                ),
                              ],
                            ),
                    ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: purple.withValues(alpha:0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          Icon(icon, color: orange, size: 28),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: purple, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: "Satoshi")),
          const SizedBox(height: 4),
        Text(label, style: TextStyle(color: purple.withValues(alpha:0.6), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSelectedDayTimeline(List<dynamic> days) {
    Map<String, dynamic>? dayData;
    for (var d in days) {
      if ((d["day"] ?? 1) == _selectedDay) {
        dayData = d as Map<String, dynamic>;
        break;
      }
    }
    
    if (dayData == null) {
      return Center(child: Text("No data for Day $_selectedDay", style: TextStyle(color: purple.withValues(alpha:0.5))));
    }

    final meals = (dayData["meals"] as List<dynamic>?) ?? [];
    if (meals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(Icons.restaurant_menu_rounded, size: 48, color: purple.withValues(alpha:0.1)),
              const SizedBox(height: 16),
              Text("Rest day. No meals planned.", style: TextStyle(color: purple.withValues(alpha:0.5), fontSize: 16)),
            ],
          ),
        ),
      );
    }

    int dailyTotal = 0;
    for (var m in meals) {
      if (m['isNote'] == true) continue;
      final cals = m['calories'];
      if (cals is int) dailyTotal += cals;
      else if (cals is String) dailyTotal += int.tryParse(cals.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }

    return Stack(
      children: [
        // Daily Total Header
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: purple.withValues(alpha:0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Total for Day $_selectedDay",
                style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                "$dailyTotal kcal",
                style: TextStyle(color: orange, fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ],
          ),
        ),
        
        // Faint vertical chronology line
        Positioned(
          left: 19, // Align with the center of the timeline icons
          top: 60, // Push down slightly to align beneath the total header
          bottom: 20,
          child: Container(
            width: 2,
            color: purple.withValues(alpha:0.1),
          ),
        ),
        
        // Meal Items
        Padding(
          padding: const EdgeInsets.only(top: 80), // Push meal cards down beneath the total header
          child: Column(
            children: meals.map((m) => _buildMealCard(m as Map<String, dynamic>)).toList(),
          ),
        ),
      ],
    );
  }

  // 5. Detail-Rich Meal Cards
  Widget _buildMealCard(Map<String, dynamic> meal) {
    final title = meal["title"] ?? meal["name"] ?? "Recipe";
    final type = meal["type"]?.toString().toUpperCase() ?? "MEAL";

    // Real nutrients from meal object
    final pRaw = meal["protein"] ?? meal["Protein"];
    final cRaw = meal["carbs"] ?? meal["Carbs"];
    final fRaw = meal["fats"] ?? meal["Fats"] ?? meal["Total Fat"];
    
    final bool hasMacros = pRaw != null && cRaw != null && fRaw != null;

    final itemCals = meal["calories"]?.toString() ?? "450"; 
    final p = pRaw?.toString() ?? "30g";
    final c = cRaw?.toString() ?? "40g";
    final f = fRaw?.toString() ?? "15g";
    final imageUrl = meal["imageUrl"];
    
    // Choose appropriate icon based on meal type
    IconData typeIcon = Icons.restaurant_rounded;
    if (type.contains("BREAKFAST")) typeIcon = Icons.wb_twilight_rounded;
    else if (type.contains("SNACK")) typeIcon = Icons.coffee_rounded;
    else if (type.contains("DINNER")) typeIcon = Icons.nights_stay_rounded;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: GestureDetector(
        onTap: () {
          // Construct an empty Recipe object so the user can at least land on the screen,
          // though ideally a real recipe ID should be passed to fetch full details.
          final tempRecipe = hidden_pantry_recipe.Recipe(
            id: meal["recipeId"] ?? "temp_${DateTime.now().millisecondsSinceEpoch}",
            name: title,
            imageUrl: imageUrl ?? "",
            minutes: 30,
            prepMinutes: 10,
            cookMinutes: 20,
            avgRating: 0.0,
            baseServings: 2,
            ingredients: [],
            directions: [],
            authorId: "meal_plan",
            category: type,
          );

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => hidden_pantry_recipe_details.RecipeDetailsScreen(
                recipe: tempRecipe,
                apiService: widget.apiService,
                recipeService: widget.recipeService,
              ),
            ),
          );
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline Node
            Container(
              width: 40,
              height: 40,
                decoration: BoxDecoration(
                color: cardColor,
                shape: BoxShape.circle,
                border: Border.all(color: orange.withValues(alpha:0.3), width: 2),
                boxShadow: [BoxShadow(color: purple.withValues(alpha:0.1), blurRadius: 4)],
              ),
              child: Icon(typeIcon, color: orange, size: 18),
            ),
            const SizedBox(width: 16),
            
            // Card Content
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: purple.withValues(alpha:0.04), blurRadius: 8, offset: const Offset(0, 4))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Card Header Area
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Thumbnail Visual
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: purple.withValues(alpha:0.05),

                                borderRadius: BorderRadius.circular(12),
                                image: imageUrl != null && imageUrl.isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(imageUrl),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: (imageUrl == null || imageUrl.isEmpty) 
                                  ? Icon(Icons.fastfood_rounded, color: purple.withValues(alpha:0.2), size: 30)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Type & Time
                                  Text(
                                    type,
                                    style: TextStyle(color: orange, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                  ),
                                  const SizedBox(height: 4),
                                  // Title
                                  Text(
                                    title,
                                    style: TextStyle(color: purple, fontSize: 16, fontWeight: FontWeight.bold),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            // Top Right Calorie Count
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: purple.withValues(alpha:0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.local_fire_department_rounded, color: orange, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    "$itemCals",
                                    style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Macro Footer
                      if (hasMacros)
                        _buildMacroFooterRow(p, c, f)
                      else
                        FutureBuilder<hidden_pantry_recipe.Recipe?>(
                          future: _fetchLiveRecipe(meal["recipeId"]),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: purple.withValues(alpha:0.02),
                                  border: Border(top: BorderSide(color: purple.withValues(alpha:0.05))),
                                ),
                                child: Center(child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: orange))),
                              );
                            }
                            final recipe = snapshot.data;
                            final liveP = recipe?.getNutrient("protein") ?? "0g";
                            final liveC = recipe?.getNutrient("carbs") ?? "0g";
                            final liveF = recipe?.getNutrient("fats") ?? "0g";
                            return _buildMacroFooterRow(liveP, liveC, liveF);
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroFooterRow(String p, String c, String f) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: purple.withValues(alpha:0.02),
        border: Border(top: BorderSide(color: purple.withValues(alpha:0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMacroTag("Protein", p, const Color(0xFF4CAF50)),
          _buildMacroTag("Carbs", c, const Color(0xFF2196F3)),
          _buildMacroTag("Fats", f, const Color(0xFFFFC107)),
        ],
      ),
    );
  }

  Widget _buildMacroTag(String label, String value, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(value, style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(width: 4),
        Text(label[0], style: TextStyle(color: purple.withValues(alpha:0.5), fontSize: 12)), // P, C, or F

      ],
    );
  }
}