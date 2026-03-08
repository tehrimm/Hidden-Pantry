import 'dart:convert';
import 'dart:io';

class DirectionStep {
  final String id;
  String text;
  File? image;
  String? imageUrl; // Remote URL for editing existing steps
  DirectionStep({required this.id, this.text = '', this.image, this.imageUrl});
}

class Recipe {
  final String id;
  final String name;
  final String? description;
  final String? category;
  final List<String> allergens;
  final String? difficulty;
  final String? servingSize;

  final int minutes;
  final int? _prepMinutes;
  final int? _cookMinutes;
  final double avgRating;
  final int reviewCount;
  final String? imageUrl;

  final String authorId;
  final String? authorName;
  final String? authorProfileImageUrl;

  final int baseServings;

  final List<IngredientItem> ingredients;
  final List<String> directions;

  /// Key-value strings ready to display in UI
  final Map<String, String>? nutrition;

  /// Tags for filtering (cuisine, dietary, course, etc.)
  final List<String> tags;

  /// Detailed steps including text and optional image URLs
  final List<Map<String, dynamic>>? stepsDetailed;

  /// Number of steps in the recipe
  final int nSteps;
  final int? totalSteps;
  final bool isNutritionistRecipe;
  final bool isPublic;

  double getServingMultiplier(int targetServings) {
    if (baseServings <= 0) return 1.0;
    if (targetServings <= 0) return 1.0;
    return targetServings / baseServings;
  }

  List<IngredientItem> getScaledIngredients(int targetServings) {
    final multiplier = getServingMultiplier(targetServings);
    return ingredients.map((item) => item.copyWith(
      quantity: item.quantity * multiplier,
      calories: item.calories != null ? item.calories! * multiplier : null,
    )).toList();
  }

  Map<String, String>? getScaledNutrition(int targetServings) {
    if (nutrition == null) return null;
    final multiplier = getServingMultiplier(targetServings);
    final scaled = <String, String>{};
    
    nutrition!.forEach((key, value) {
      final numericPart = RegExp(r'(\d+\.?\d*)').firstMatch(value)?.group(1);
      final unitPart = value.replaceAll(RegExp(r'[\d\.]'), '').trim();
      
      if (numericPart != null) {
        final val = double.parse(numericPart) * multiplier;
        final whole = (val - val.roundToDouble()).abs() < 0.0001;
        final fmtVal = whole ? val.round().toString() : val.toStringAsFixed(1);
        scaled[key] = "$fmtVal $unitPart".trim();
      } else {
        scaled[key] = value;
      }
    });
    return scaled;
  }

  double get calculatedTotalCalories {
    if (nutrition != null && nutrition!.containsKey('Calories')) {
      final calStr = nutrition!['Calories']!;
      final match = RegExp(r'(\d+\.?\d*)').firstMatch(calStr);
      if (match != null) return double.parse(match.group(1)!);
    }
    // Fallback: Sum ingredient calories
    return ingredients.fold(0.0, (sum, item) => sum + (item.calories ?? 0.0));
  }

  int get prepMinutes => _prepMinutes ?? (minutes < 20 ? minutes : 15);
  int get cookMinutes => _cookMinutes ?? (minutes < 20 ? 0 : (minutes - 15));

  String getNutrient(String name) {
    if (nutrition == null) return "0g";
    final keyLower = name.toLowerCase();
    
    // 1. Direct case-insensitive match
    for (final entry in nutrition!.entries) {
      if (entry.key.toLowerCase() == keyLower) return entry.value;
    }
    
    // 2. Common aliases
    final aliases = {
      'protein': ['p', 'proteins'],
      'carbs': ['carbohydrates', 'carb', 'c', 'total carbohydrates'],
      'fats': ['fat', 'total fat', 'fats', 'f'],
      'calories': ['kcal', 'energy', 'cal'],
    };
    
    if (aliases.containsKey(keyLower)) {
      for (final alias in aliases[keyLower]!) {
        for (final entry in nutrition!.entries) {
          if (entry.key.toLowerCase() == alias) return entry.value;
        }
      }
    }
    
    return "0g";
  }

  const Recipe({
    required this.id,
    required this.name,
    this.description,
    this.category,
    this.allergens = const [],
    this.difficulty,
    this.servingSize,
    required this.minutes,
    int? prepMinutes,
    int? cookMinutes,
    required this.avgRating,
    this.reviewCount = 0,
    this.imageUrl,
    this.authorId = "",
    this.authorName,
    this.authorProfileImageUrl,
    this.baseServings = 1,
    this.ingredients = const [],
    this.directions = const [],
    this.nutrition,
    this.tags = const [],
    this.stepsDetailed,
    this.nSteps = 0,
    this.totalSteps,
    this.isNutritionistRecipe = false,
    this.isPublic = true,
  })  : _prepMinutes = prepMinutes,
        _cookMinutes = cookMinutes;

  // =======================
  // Helpers
  // =======================
  static int _toInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    
    final s = v.toString().trim();
    final direct = int.tryParse(s);
    if (direct != null) return direct;

    // Try to extract the first number found in the string (e.g. "16 servings")
    final match = RegExp(r'(\d+)').firstMatch(s);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? fallback;
    }

    return fallback;
  }

  static double _toDouble(dynamic v, {double fallback = 0.0}) {
    if (v == null) return fallback;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? fallback;
  }

  static String? _cleanNullableString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty || s.toLowerCase() == "null") return null;
    return s;
  }

  static String _fmtNum(dynamic v) {
    if (v == null) return "-";
    if (v is num) {
      final d = v.toDouble();
      final whole = (d - d.roundToDouble()).abs() < 0.0001;
      return whole ? d.round().toString() : d.toStringAsFixed(1);
    }
    final s = v.toString().trim();
    if (s.isEmpty) return "-";

    // if numeric string, normalize it
    final parsed = double.tryParse(s);
    if (parsed != null) {
      final whole = (parsed - parsed.roundToDouble()).abs() < 0.0001;
      return whole ? parsed.round().toString() : parsed.toStringAsFixed(1);
    }
    return s;
  }

  static String _stripHtml(String html) {
    // Basic regex to remove HTML tags but keep the content inside them
    // e.g. <a href="foo">bar</a> -> bar
    return html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }

  /// Turns:
  /// - List -> same list
  /// - String like '["a","b"]' -> list
  /// - String like "['a', 'b']" -> tries to convert to JSON then list
  static List<dynamic> _coerceList(dynamic v) {
    if (v == null) return const [];
    if (v is List) return v;

    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return const [];
      if (s.startsWith('[') && s.endsWith(']')) {
        // Try proper JSON first
        try {
          final decoded = jsonDecode(s);
          if (decoded is List) return decoded;
        } catch (_) {
          // Try single-quote list -> JSON-ish
          // NOTE: This is a best-effort fix for strings like: ['a', 'b']
          final maybeJson = s.replaceAll("'", '"');
          try {
            final decoded = jsonDecode(maybeJson);
            if (decoded is List) return decoded;
          } catch (_) {
            // last fallback: return as single item
            return [s];
          }
        }
      }
      return [s];
    }

    return const [];
  }

  static List<String> _toStringList(dynamic v) {
    final list = _coerceList(v);
    return list
        .map((e) => _stripHtml(e.toString()))
        .where((s) => s.isNotEmpty && s.toLowerCase() != "null")
        .toList();
  }

  // =======================
  // Parsers
  // =======================
  static Map<String, String>? _parseNutrition(Map<String, dynamic> json) {
    // Case A: nested nutrition map exists
    final n = json['nutrition'];
    if (n is Map) {
      final m = n.map((k, v) => MapEntry(k.toString(), v.toString()));
      if (m.isEmpty) return null;
      return Map<String, String>.from(m);
    }

    // Case B: top-level fields (your FastAPI index)
    final hasAny = [
      json['calories'],
      json['protein'],
      json['carbs'],
      json['total_fat'],
      json['sat_fat'],
      json['sugar'],
      json['sodium'],
    ].any((e) => e != null);

    if (!hasAny) return null;

    return <String, String>{
      "Calories": "${_fmtNum(json['calories'])} kcal",
      "Protein": "${_fmtNum(json['protein'])} g",
      "Carbs": "${_fmtNum(json['carbs'])} g",
      "Total Fat": "${_fmtNum(json['total_fat'])} g",
      "Sat. Fat": "${_fmtNum(json['sat_fat'])} g",
      "Sugar": "${_fmtNum(json['sugar'])} g",
      "Sodium": "${_fmtNum(json['sodium'])} mg",
    };
  }

  static List<IngredientItem> _parseIngredients(Map<String, dynamic> json) {
    // 1. Try preferred: ingredients_parsed (list of maps or map-strings)
    final parsed = json['ingredients_parsed'];
    if (parsed != null) {
      final list = _coerceList(parsed);
      final out = <IngredientItem>[];
      for (final e in list) {
        final item = _parseSingleIngredient(e);
        if (item != null) out.add(item);
      }
      if (out.isNotEmpty) return out;
    }

    // 2. Try fallback: ingredients (list of strings or map-strings)
    final ing = json['ingredients'];
    if (ing != null) {
      final list = _coerceList(ing);
      final out = <IngredientItem>[];
      for (final e in list) {
        final item = _parseSingleIngredient(e);
        if (item != null) out.add(item);
      }
      if (out.isNotEmpty) return out;
    }

    return const [];
  }

  static IngredientItem? _parseSingleIngredient(dynamic e) {
    if (e == null) return null;

    // Case A: Actual Map object
    if (e is Map) {
      return IngredientItem.fromJson(Map<String, dynamic>.from(e));
    }

    // Case B: String (could be a name OR a stringified map)
    if (e is String) {
      final s = e.trim();
      if (s.isEmpty) return null;

      // Check if it looks like a map string: {name: ..., quantiy: ...}
      if (s.contains('name') && (s.contains('{') || s.contains('(') || s.contains(':'))) {
        try {
          // Use regex to extract parts from messy strings, handling optional quotes around keys
          // Use robust regex to extract parts, allowing for quoted/unquoted keys and various delimiters
          final nameMatch = RegExp(r'''['"]?name['"]?\s*[:=]\s*['"]?([^,}'"]+)['"]?''', caseSensitive: false).firstMatch(s);
          final qtyMatch = RegExp(r'''['"]?quantit[y]?['"]?\s*[:=]\s*['"]?([^,}'" ]+)['"]?''', caseSensitive: false).firstMatch(s);
          final unitMatch = RegExp(r'''['"]?unit['"]?\s*[:=]\s*['"]?([^,;)}'"]+)''', caseSensitive: false).firstMatch(s);

          if (nameMatch != null) {
            String name = nameMatch.group(1)!.trim();
            // Remove lingering quotes
            if (name.startsWith("'") || name.startsWith('"')) name = name.substring(1);
            if (name.endsWith("'") || name.endsWith('"')) name = name.substring(0, name.length - 1);
            name = name.trim();

            String qtyStr = qtyMatch?.group(1)?.trim() ?? "0";
            double qty = double.tryParse(qtyStr) ?? 0.0;

            String unit = unitMatch?.group(1)?.trim() ?? "";
            if (unit.startsWith("'") || unit.startsWith('"')) unit = unit.substring(1);
            if (unit.endsWith("'") || unit.endsWith('"')) unit = unit.substring(0, unit.length - 1);
            unit = unit.trim();

            return IngredientItem(name: name, quantity: qty, unit: unit);
          }
        } catch (err) {
          print("[Recipe] Error smart-parsing ingredient string: $s - $err");
        }
      }

      // Default: treated as just a name
      return IngredientItem(name: s, quantity: 0.0, unit: "");
    }

    return null;
  }

  static List<String> _parseDirections(Map<String, dynamic> json) {
    // Your API can contain both, so handle both + stringified cases
    final raw = json['directions'] ?? json['steps'];
    final list = _toStringList(raw);

    // Some datasets accidentally put all steps in one long string
    // If we only got 1 item and it contains newline bullets, split it
    if (list.length == 1) {
      final one = list.first;
      final maybeSplit = one
          .split(RegExp(r'(\r?\n)+|•|-\s+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (maybeSplit.length >= 2) return maybeSplit;
    }

    return list;
  }

  // =======================
  // Factory
  // =======================
  factory Recipe.fromJson(Map<String, dynamic> json) {
    // Some APIs wrap the recipe in a 'recipe' or 'data' key.
    final data = (json['recipe'] is Map<String, dynamic>) 
        ? json['recipe'] as Map<String, dynamic>
        : (json['data'] is Map<String, dynamic>)
            ? json['data'] as Map<String, dynamic>
            : json;

    final img = _cleanNullableString(
      data['image'] ?? 
      data['imageUrl'] ?? 
      data['image_url'] ?? 
      data['recipe_image'] ?? 
      data['recipe_imageUrl'] ??
      data['recipeImageUrl'] ??
      data['recipe_image_url'] ??
      data['recipe_img'] ??
      data['img_url'] ??
      data['imagePath']
    );

    final servingSizeText = _cleanNullableString(
      data['serving_size'] ?? 
      data['servingSize'] ?? 
      data['servings'] ??
      data['serves'] ??
      data['yields']
    );

    return Recipe(
      id: (data['id'] ?? data['recipe_id'] ?? data['recipeId'] ?? data['_id'] ?? "").toString(),
      name: (
        data['name'] ?? 
        data['title'] ?? 
        data['recipe_name'] ?? 
        data['recipeName'] ?? 
        data['label'] ?? 
        data['recipe_title'] ??
        data['recipeTitle'] ??
        data['display_name'] ??
        ""
      ).toString(),
      description: _cleanNullableString(data['description'] ?? data['recipe_description'] ?? data['summary']),
      category: _cleanNullableString(data['category'] ?? data['recipe_category']),
      allergens: _toStringList(data['allergens']),
      difficulty: _cleanNullableString(data['difficulty']),
      servingSize: servingSizeText,
      minutes: _toInt(
        data['readyInMinutes'] ?? 
        data['minutes'] ?? 
        data['total_time'] ?? 
        data['totalTime'] ?? 
        data['cook_time'] ?? 
        data['cookTime'] ??
        data['prep_time'], 
        fallback: _toInt(data['prepTime'] ?? 0) + _toInt(data['cookTime'] ?? 0)
      ),
      prepMinutes: _toInt(data['prep_minutes'] ?? data['prep_time'] ?? data['prepMinutes'] ?? data['prepTime']),
      cookMinutes: _toInt(data['cook_minutes'] ?? data['cook_time'] ?? data['cookMinutes'] ?? data['cookTime']),
      avgRating: _toDouble(
        data['avg_rating'] ?? 
        data['avgRating'] ?? 
        data['aggregateRating'] ?? 
        data['recipe_average_rating'] ?? 
        data['rating'], 
        fallback: 0.0
      ),
      reviewCount: _toInt(data['review_count'] ?? data['reviews'] ?? data['ratingsCount'] ?? data['reviewCount']),
      imageUrl: img,
      authorId: (data['author_id'] ?? data['authorId'] ?? "").toString(),
      authorName: _cleanNullableString(data['author_name'] ?? data['authorName'] ?? data['sourceName']),
      authorProfileImageUrl: _cleanNullableString(
        data['author_profile_image_url'] ??
            data['author_profile'] ??
            data['authorProfileImageUrl'],
      ),
      baseServings: () {
        // 1. Try to extract from the textual serving size first (e.g. "4 servings")
        if (servingSizeText != null && servingSizeText.isNotEmpty) {
           final match = RegExp(r'\d+').firstMatch(servingSizeText);
           if (match != null) {
             final parsed = int.parse(match.group(0)!);
             if (parsed > 0) return parsed;
           }
        }
        
        // 2. Fallback to other possible numeric keys (which might include a cached 1)
        final keys = [
          'base_servings', 'baseServings', 'servings', 'n_servings'
        ];
        for (final k in keys) {
          if (data.containsKey(k) && data[k] != null) {
            final val = data[k];
            int parsed = 0;
            if (val is int) {
               parsed = val;
            } else if (val is double) {
               parsed = val.round();
            } else if (val is String) {
               final match = RegExp(r'\d+').firstMatch(val);
               if (match != null) {
                 parsed = int.parse(match.group(0)!);
               }
            }
            if (parsed > 0) return parsed;
          }
        }
        return 1;
      }(),
      ingredients: _parseIngredients(data),
      directions: _parseDirections(data),
      nutrition: _parseNutrition(data),
      tags: _toStringList(data['tags'] ?? data['cuisines'] ?? data['dishTypes'] ?? data['tags_parsed']),
      stepsDetailed: (data['steps_detailed'] as List?)?.cast<Map<String, dynamic>>() ?? 
                     (data['analyzedInstructions'] != null && (data['analyzedInstructions'] as List).isNotEmpty 
                        ? (data['analyzedInstructions'][0]['steps'] as List?)?.cast<Map<String, dynamic>>() 
                        : null),
      nSteps: _toInt(data['n_steps'] ?? data['total_steps'] ?? data['instructions']?.toString().split('.').length, fallback: 0),
      totalSteps: _toInt(data['total_steps']),
      isNutritionistRecipe: data['is_nutritionist_recipe'] == true,
      isPublic: data['is_public'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'name_search': name.toLowerCase(),
      'description': description,
      'difficulty': difficulty,
      'minutes': minutes,
      'prepTime': _prepMinutes,
      'cookTime': _cookMinutes,
      'prep_minutes': _prepMinutes,
      'cook_minutes': _cookMinutes,
      'avg_rating': avgRating,
      'review_count': reviewCount,
      'image_url': imageUrl,
      'author_id': authorId,
      'author_name': authorName,
      'author_profile_image_url': authorProfileImageUrl,
      'base_servings': baseServings,
      'servings': baseServings,
      'ingredients': ingredients.map((e) => e.toJson()).toList(),
      'directions': directions,
      'nutrition': nutrition,
      'tags': tags,
      'steps_detailed': stepsDetailed,
      'n_steps': nSteps,
      'is_nutritionist_recipe': isNutritionistRecipe,
      'is_public': isPublic,
    };
  }

  Recipe copyWith({
    String? id,
    String? name,
    double? avgRating,
    int? reviewCount,
    String? authorId,
    String? authorName,
    String? authorProfileImageUrl,
    List<IngredientItem>? ingredients,
    List<String>? directions,
    String? difficulty,
    bool? isPublic,
  }) {
    return Recipe(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description,
      category: category,
      allergens: allergens,
      difficulty: difficulty ?? this.difficulty,
      servingSize: servingSize,
      minutes: minutes,
      prepMinutes: _prepMinutes,
      cookMinutes: _cookMinutes,
      avgRating: avgRating ?? this.avgRating,
      reviewCount: reviewCount ?? this.reviewCount,
      imageUrl: imageUrl,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorProfileImageUrl: authorProfileImageUrl ?? this.authorProfileImageUrl,
      baseServings: baseServings,
      ingredients: ingredients ?? this.ingredients,
      directions: directions ?? this.directions,
      nutrition: nutrition,
      tags: tags,
      stepsDetailed: stepsDetailed,
      nSteps: nSteps,
      totalSteps: totalSteps,
      isNutritionistRecipe: isNutritionistRecipe,
      isPublic: isPublic ?? this.isPublic,
    );
  }
}

class IngredientItem {
  final String name;
  final double quantity;
  final String unit;
  final double? calories;

  const IngredientItem({
    required this.name,
    required this.quantity,
    required this.unit,
    this.calories,
  });

  IngredientItem copyWith({
    String? name,
    double? quantity,
    String? unit,
    double? calories,
  }) {
    return IngredientItem(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      calories: calories ?? this.calories,
    );
  }

  static double _toDouble(dynamic v, {double fallback = 0.0}) {
    if (v == null) return fallback;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    
    final s = v.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
    if (s.isEmpty) return fallback;

    // Handle mixed fractions like "1 1/2" or simple "1/2"
    if (s.contains('/')) {
      try {
        final spaceIdx = s.indexOf(' ');
        if (spaceIdx != -1) {
          // Mixed: "1 1/2"
          final wholePart = double.tryParse(s.substring(0, spaceIdx)) ?? 0.0;
          final fractionPart = s.substring(spaceIdx + 1);
          final parts = fractionPart.split('/');
          if (parts.length == 2) {
            final numPart = double.tryParse(parts[0].trim());
            final denPart = double.tryParse(parts[1].trim());
            if (numPart != null && denPart != null && denPart != 0) {
              return wholePart + (numPart / denPart);
            }
          }
        } else {
          // Simple: "1/2"
          final parts = s.split('/');
          if (parts.length == 2) {
            final numPart = double.tryParse(parts[0].trim());
            final denPart = double.tryParse(parts[1].trim());
            if (numPart != null && denPart != null && denPart != 0) {
              return numPart / denPart;
            }
          }
        }
      } catch (_) {}
    }

    return double.tryParse(s) ?? fallback;
  }

  factory IngredientItem.fromJson(Map<String, dynamic> json) {
    String name = (json['name'] ?? json['ingredient'] ?? "").toString();
    double quantity = _toDouble(json['quantity'] ?? json['quantiy'], fallback: 0.0);
    String unit = (json['unit'] ?? "").toString();
    double? calories = json['calories'] != null ? _toDouble(json['calories']) : null;

    // EXTRA ROBUSTNESS: If name itself looks like a stringified map
    // (Happens if backend incorrectly stringifies the whole object into the name field)
    // Check for "name" and either braces or colon to suspect a stringified map
    if (name.contains('name') && (name.contains('{') || name.contains(':') || name.contains('('))) {
      final smartParsed = Recipe._parseSingleIngredient(name);
      if (smartParsed != null && smartParsed.name != name) {
        return smartParsed;
      }
    }

    // Strip HTML tags if any
    name = name.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    unit = unit.replaceAll(RegExp(r'<[^>]*>'), '').trim();

    return IngredientItem(
      name: name,
      quantity: quantity,
      unit: unit,
      calories: calories,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'calories': calories,
    };
  }
}



