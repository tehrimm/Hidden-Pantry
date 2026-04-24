class MealPlan {
  final String id;
  final String title;
  final String? notes;
  final int duration;
  final int targetCalories;
  final List<DailyMeal> days;

  MealPlan({
    required this.id,
    required this.title,
    this.notes,
    required this.duration,
    required this.targetCalories,
    required this.days,
  });

  factory MealPlan.fromJson(Map<String, dynamic> json, {String? docId}) {
    return MealPlan(
      id: docId ?? json['planId'] ?? '',
      title: json['title'] ?? 'Untitled Plan',
      notes: json['notes'],
      duration: json['duration'] ?? 0,
      targetCalories: json['targetCalories'] ?? 0,
      days: (json['days'] as List<dynamic>?)
              ?.map((d) => DailyMeal.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class DailyMeal {
  final int day;
  final List<MealItem> meals;

  DailyMeal({required this.day, required this.meals});

  factory DailyMeal.fromJson(Map<String, dynamic> json) {
    return DailyMeal(
      day: json['day'] ?? 1,
      meals: (json['meals'] as List<dynamic>?)
              ?.map((m) => MealItem.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class MealItem {
  final String title;
  final String type;
  final String? recipeId;
  final String? calories;
  final String? protein;
  final String? carbs;
  final String? fats;
  final String? imageUrl;
  final bool isNote;
  final String? note;

  MealItem({
    required this.title,
    required this.type,
    this.recipeId,
    this.calories,
    this.protein,
    this.carbs,
    this.fats,
    this.imageUrl,
    this.isNote = false,
    this.note,
  });

  factory MealItem.fromJson(Map<String, dynamic> json) {
    return MealItem(
      title: json['title'] ?? json['name'] ?? 'Meal',
      type: json['type'] ?? 'meal',
      recipeId: json['recipeId'],
      calories: json['calories']?.toString(),
      protein: json['protein']?.toString(),
      carbs: json['carbs']?.toString(),
      fats: json['fats']?.toString(),
      imageUrl: json['imageUrl'],
      isNote: json['isNote'] ?? false,
      note: json['note'],
    );
  }
}
