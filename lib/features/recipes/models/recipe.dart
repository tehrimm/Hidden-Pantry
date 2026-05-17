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
      // Searching for a primary group (e.g. "protein") -> check all its aliases in nutrition map
      for (final alias in aliases[keyLower]!) {
        for (final entry in nutrition!.entries) {
          if (entry.key.toLowerCase() == alias) return entry.value;
        }
      }
    } else {
      // Searching for an alias (e.g. "carbohydrates") -> find which group it belongs to
      for (final group in aliases.entries) {
        if (group.value.contains(keyLower)) {
          // It belongs to this group. Check if nutrition has the group name itself
          for (final entry in nutrition!.entries) {
            if (entry.key.toLowerCase() == group.key) return entry.value;
          }
          // OR if nutrition has any OTHER alias from this same group
          for (final otherAlias in group.value) {
            for (final entry in nutrition!.entries) {
              if (entry.key.toLowerCase() == otherAlias) return entry.value;
            }
          }
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

  static IngredientItem? parseIngredient(dynamic e) {
    if (e == null) return null;
    return IngredientItem.fromJson(e);
  }

  static List<IngredientItem> _parseIngredients(Map<String, dynamic> json) {
    // 1. Try preferred: ingredients (raw strings are safer because backend NLP often corrupts them)
    final ing = json['ingredients'];
    if (ing != null) {
      final list = _coerceList(ing);
      final out = <IngredientItem>[];
      for (final e in list) {
        final item = parseIngredient(e);
        if (item != null) out.add(item);
      }
      if (out.isNotEmpty) return out;
    }

    // 2. Try fallback: ingredients_parsed
    final parsed = json['ingredients_parsed'];
    if (parsed != null) {
      final list = _coerceList(parsed);
      final out = <IngredientItem>[];
      for (final e in list) {
        final item = parseIngredient(e);
        if (item != null) out.add(item);
      }
      if (out.isNotEmpty) return out;
    }

    return const [];
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
      prepMinutes: (() {
        final raw = data['prep_minutes'] ?? data['prep_time'] ?? data['prepMinutes'] ?? data['prepTime'];
        if (raw == null) return null;
        return _toInt(raw);
      })(),
      cookMinutes: (() {
        final raw = data['cook_minutes'] ?? data['cook_time'] ?? data['cookMinutes'] ?? data['cookTime'];
        if (raw == null) return null;
        return _toInt(raw);
      })(),
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
      'allergens': allergens,
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
  final String? displayQuantity; // Added this missing line
  final double? calories;

  const IngredientItem({
    required this.name,
    required this.quantity,
    required this.unit,
    this.displayQuantity, // Added this
    this.calories,
  });

  IngredientItem copyWith({
    String? name,
    double? quantity,
    String? unit,
    String? displayQuantity,
    double? calories,
  }) {
    return IngredientItem(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      displayQuantity: displayQuantity ?? this.displayQuantity,
      calories: calories ?? this.calories,
    );
  }

  static double toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    String s = v.toString().trim().toLowerCase();
    if (s.isEmpty) return 0.0;

    // Handle Ranges
    for (var delim in [' to ', '-', '–']) {
      if (s.contains(delim)) {
        var parts = s.split(delim);
        if (parts.length >= 2) {
          return (toDouble(parts[0]) + toDouble(parts[1])) / 2.0;
        }
      }
    }

    try {
      if (s.contains('/')) {
        var parts = s.split(' ');
        double total = 0;
        for (var p in parts) {
          if (p.contains('/')) {
            var f = p.split('/');
            total += double.parse(f[0]) / double.parse(f[1]);
          } else if (p.isNotEmpty) {
            total += double.parse(p);
          }
        }
        return total;
      }
      return double.parse(s);
    } catch (e) {
      return 0.0;
    }
  }

  factory IngredientItem.fromJson(dynamic json) {
    if (json == null) return IngredientItem(name: "", quantity: 0, unit: "");

    if (json is Map) {
      final name = (json['name'] ?? json['ingredient'] ?? "").toString();
      final qtyVal = json['quantity'] ?? json['quantiy'] ?? 0;
      final unit = (json['unit'] ?? "").toString().toLowerCase();
      final displayQuantity = json['displayQuantity']?.toString();

      final parsedQty = toDouble(qtyVal);
      final finalDisplayQty = (displayQuantity == null || displayQuantity.trim().isEmpty) && parsedQty == 0
          ? "as needed"
          : displayQuantity;

      return IngredientItem(
        name: name,
        quantity: parsedQty,
        unit: unit,
        displayQuantity: finalDisplayQty,
      );
    }

    // Case: Input is a string (e.g., "1 cup milk" or "to taste salt")
    String s = json.toString().trim();
    if (s.isEmpty) return const IngredientItem(name: "", quantity: 0, unit: "");

    String displayQuantity = "";
    String unit = "";
    String name = s;

    // 1. Detect Special Prefixes (to taste, as needed, handful)
    final prefixes = [
      RegExp(r'^to\s+taste\b', caseSensitive: false),
      RegExp(r'^as\s+needed\b', caseSensitive: false),
      RegExp(r'^handful\b', caseSensitive: false),
      RegExp(r'^a\s+handful\b', caseSensitive: false),
    ];

    for (var pattern in prefixes) {
      if (pattern.hasMatch(s)) {
        displayQuantity = pattern.firstMatch(s)![0]!.toLowerCase();
        name = s.replaceFirst(pattern, '').trim();
        name = name.replaceFirst(RegExp(r'^of\s+', caseSensitive: false), '').trim();
        return IngredientItem(
          name: name,
          quantity: 0,
          unit: "",
          displayQuantity: displayQuantity,
        );
      }
    }

    // Check for "to taste" at the end
    final tasteSuffix = RegExp(r'\s+to\s+taste\s*$', caseSensitive: false);
    if (tasteSuffix.hasMatch(s)) {
      displayQuantity = "to taste";
      name = s.replaceFirst(tasteSuffix, '').trim();
      name = name.replaceAll(RegExp(r',$'), '').trim();
      return IngredientItem(
        name: name,
        quantity: 0,
        unit: "",
        displayQuantity: displayQuantity,
      );
    }

    // 2. Parse Quantity (Numbers, Fractions, Ranges)
    final qtyRegex = RegExp(r'^(\d+[\d\s\./¼½¾⅓⅔⅛⅜⅝⅞-]*?)(?=\s+[a-zA-Z]|$)');
    final qtyMatch = qtyRegex.firstMatch(s);

    if (qtyMatch != null) {
      String rawQty = qtyMatch.group(1)!.trim();
      displayQuantity = rawQty;
      name = s.substring(qtyMatch.end).trim();

      // 3. Detect Unit
      final units = [
        'tablespoons', 'tablespoon', 'tbsp', 'tbs',
        'teaspoons', 'teaspoon', 'tsp', 'ts',
        'cups', 'cup', 'c', 'ounces', 'ounce', 'oz',
        'pounds', 'pound', 'lbs', 'lb', 'grams', 'gram', 'g',
        'kg', 'ml', 'l', 'cloves', 'clove', 'can', 'pkg', 'slices', 'slice',
        'pinch', 'dash', 'sticks', 'stick', 'handful', 'handfuls', 'ears', 'stalk', 'stalks'
      ];
      units.sort((a, b) => b.length.compareTo(a.length));
      final unitRegex = RegExp('^(${units.join('|')})\\b', caseSensitive: false);
      final unitMatch = unitRegex.firstMatch(name);

      if (unitMatch != null) {
        unit = unitMatch.group(1)!.toLowerCase();
        name = name.substring(unitMatch.end).trim();
      }

      // Cleanup
      name = name.replaceFirst(RegExp(r'^of\s+', caseSensitive: false), '').trim();
      name = name.replaceFirst(RegExp(r'^,\s*'), '').trim();

      return IngredientItem(
        name: name,
        quantity: toDouble(rawQty),
        unit: unit,
        displayQuantity: displayQuantity,
      );
    }

    return IngredientItem(name: s, quantity: 0, unit: "", displayQuantity: "as needed");
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'displayQuantity': displayQuantity,
      'calories': calories,
    };
  }
}
