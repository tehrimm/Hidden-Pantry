class MealPlan {
  final String id;
  final String title;
  final String? notes;
  final int duration;
  final List<DailyMeal> days;

  MealPlan({
    required this.id,
    required this.title,
    this.notes,
    required this.duration,
    required this.days,
  });

  factory MealPlan.fromJson(Map<String, dynamic> json, {String? docId}) {
    return MealPlan(
      id: docId ?? json['planId'] ?? '',
      title: json['title'] ?? 'Untitled Plan',
      notes: json['notes'],
      duration: json['duration'] ?? 0,
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

  MealItem({
    required this.title,
    required this.type,
    this.recipeId,
    this.calories,
  });

  factory MealItem.fromJson(Map<String, dynamic> json) {
    return MealItem(
      title: json['title'] ?? json['name'] ?? 'Meal',
      type: json['type'] ?? 'meal',
      recipeId: json['recipeId'],
      calories: json['calories']?.toString(),
    );
  }
}
