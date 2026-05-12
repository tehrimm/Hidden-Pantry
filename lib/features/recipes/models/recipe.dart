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
        final item = parseIngredient(e);
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
        final item = parseIngredient(e);
        if (item != null) out.add(item);
      }
      if (out.isNotEmpty) return out;
    }

    return const [];
  }

  static IngredientItem? parseIngredient(dynamic e) {
    if (e == null) return null;

    if (e is Map) {
      return IngredientItem.fromJson(Map<String, dynamic>.from(e));
    }

    if (e is String) {
      String s = e.trim();
      if (s.isEmpty) return null;

      // 1. SMART REPAIR FOR TRUNCATED STRINGS
      String low = s.toLowerCase();
      if (low.startsWith("ablespoon")) s = "t$s";
      else if (low.startsWith("easpoon")) s = "t$s";
      else if (low.startsWith("unces")) s = "o$s";
      else if (low.startsWith("arge ")) s = "l$s";
      else if (low.startsWith("emon ")) s = "l$s";

      // 2. Check for stringified Map (messy backend data)
      if (s.contains('name') && (s.contains('{') || s.contains(':'))) {
        try {
          final nameMatch = RegExp(r'''['"]?name['"]?\s*[:=]\s*['"]?([^,}'"]+)['"]?''', caseSensitive: false).firstMatch(s);
          final qtyMatch = RegExp(r'''['"]?quantit[y]?['"]?\s*[:=]\s*['"]?([^,}'" ]+)['"]?''', caseSensitive: false).firstMatch(s);
          final unitMatch = RegExp(r'''['"]?unit['"]?\s*[:=]\s*['"]?([^,;)}'"]+)''', caseSensitive: false).firstMatch(s);

          if (nameMatch != null) {
            String name = nameMatch.group(1)!.trim().replaceAll("'", "").replaceAll('"', "");
            String qtyStr = qtyMatch?.group(1)?.trim().replaceAll("'", "").replaceAll('"', "") ?? "1";
            String unit = unitMatch?.group(1)?.trim().replaceAll("'", "").replaceAll('"', "") ?? "";

            return IngredientItem(
              name: name, 
              quantity: IngredientItem.toDouble(qtyStr), 
              unit: unit.toLowerCase()
            );
          }
        } catch (_) {}
      }

      // 3. Robust Word-Based Parsing
      final commonUnits = {
        'tablespoon', 'tablespoons', 'teaspoon', 'teaspoons',
        'tbsp', 'tbsp.', 'tbsps.', 'tbs', 'tbs.', 
        'tsp', 'tsp.', 'tsps.', 'ts', 'ts.',
        'cup', 'cups', 'oz', 'ounce', 'ounces', 'can', 'cans', 'lb', 'pound', 
        'pounds', 'g', 'gram', 'grams', 'kg', 'kilogram', 'kilograms', 
        'ml', 'milliliter', 'milliliters', 'l', 'liter', 'liters', 'pkg', 'package',
        'slice', 'slices', 'piece', 'pieces', 'clove', 'cloves', 'stick', 'sticks',
        'pinch', 'pinches', 'dash', 'dashes', 'handful', 'handfuls', 'head', 'heads',
        'fluid ounce', 'fluid ounces', 'fl oz', 'fl. oz.'
      };

      String qtyPart = "";
      String unitPart = "";
      String namePart = "";

      // 3.1. Extract leading quantity
      final qtyRegex = RegExp(r'^([0-9\s\./¼½¾⅓⅔⅛⅜⅝⅞-]+(?:\s+to\s+[0-9\s\./¼½¾⅓⅔⅛⅜⅝⅞-]+)?)', caseSensitive: false);
      final qtyMatch = qtyRegex.firstMatch(s);
      String remaining = s;
      
      if (qtyMatch != null) {
        qtyPart = qtyMatch.group(1)!.trim();
        remaining = s.substring(qtyMatch.end).trim();
      }

      if (remaining.isNotEmpty) {
        // 3.2. Check for multi-word units first (e.g., "fluid ounce")
        bool multiWordFound = false;
        final multiWordUnits = commonUnits.where((u) => u.contains(' ')).toList()
          ..sort((a, b) => b.length.compareTo(a.length));
        
        for (final unit in multiWordUnits) {
          if (remaining.toLowerCase().startsWith("$unit ")) {
            unitPart = unit;
            namePart = remaining.substring(unit.length).trim();
            multiWordFound = true;
            break;
          } else if (remaining.toLowerCase() == unit) {
            unitPart = unit;
            namePart = "";
            multiWordFound = true;
            break;
          }
        }

        if (!multiWordFound) {
          // 3.3. Check first word for unit
          final words = remaining.split(RegExp(r'\s+'));
          final firstWord = words.first.toLowerCase();
          
          // Clean first word of trailing punctuation for comparison
          final cleanFirstWord = firstWord.replaceAll(RegExp(r'[.,;]$'), '');
          
          if (commonUnits.contains(firstWord) || commonUnits.contains(cleanFirstWord)) {
            unitPart = firstWord;
            namePart = words.skip(1).join(" ").trim();
          } else {
            // 3.4. Handle attached units like "10g" if qtyRegex missed them or they are mixed
            // Check if firstWord starts with numbers and ends with a unit
            final attachedMatch = RegExp(r'^(\d+)([a-zA-Z]+)$').firstMatch(firstWord);
            if (attachedMatch != null) {
              final potentialQty = attachedMatch.group(1)!;
              final potentialUnit = attachedMatch.group(2)!.toLowerCase();
              if (commonUnits.contains(potentialUnit)) {
                qtyPart = qtyPart.isEmpty ? potentialQty : "$qtyPart $potentialQty";
                unitPart = potentialUnit;
                namePart = words.skip(1).join(" ").trim();
              } else {
                namePart = remaining;
              }
            } else {
              namePart = remaining;
            }
          }
        }
      }

      if (qtyPart.isEmpty) qtyPart = "1";

      String cleanName = namePart.trim();
      if (cleanName.toLowerCase().startsWith("of ")) cleanName = cleanName.substring(3).trim();
      
      // Remove leading/trailing parentheses and noise
      final noise = RegExp(r'^[(),.\s]+|[(),.\s]+$');
      cleanName = cleanName.replaceAll(noise, '').trim();

      return IngredientItem(
        name: cleanName.isEmpty ? (unitPart.isEmpty ? qtyPart : unitPart) : cleanName,
        quantity: IngredientItem.toDouble(qtyPart),
        displayQuantity: qtyPart, // Store the exact string
        unit: unitPart,
      );
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

  static double toDouble(dynamic v, {double fallback = 0.0}) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    
    final s = v.toString().trim();
    if (s.isEmpty) return fallback;

    // 1. Direct Parse
    final direct = double.tryParse(s);
    if (direct != null) return direct;

    // 2. Handle Ranges: "1 to 2" or "1-2"
    if (s.contains(' to ') || (s.contains('-') && !s.startsWith('-'))) {
      final parts = s.split(RegExp(r'\s+to\s+|-'));
      if (parts.length >= 2) {
        final v1 = toDouble(parts[0].trim());
        final v2 = toDouble(parts[1].trim());
        if (v1 > 0 && v2 > 0) return (v1 + v2) / 2;
        if (v1 > 0) return v1;
      }
    }

    // 3. Range Handling: "1/4-1/2" or "1-2"
    if (s.contains('-')) {
      final parts = s.split('-');
      if (parts.length == 2) {
        final val1 = toDouble(parts[0], fallback: -1);
        final val2 = toDouble(parts[1], fallback: -1);
        if (val1 != -1 && val2 != -1) {
          return (val1 + val2) / 2; // Return average for ranges
        } else if (val1 != -1) {
          return val1;
        }
      }
    }

    // 4. Mixed Fractions: "1 1/2"
    final mixedMatch = RegExp(r'^(\d+)\s+(\d+)/(\d+)').firstMatch(s);

    // 4. Simple Fractions: "3/4"
    final fracMatch = RegExp(r'(\d+)/(\d+)').firstMatch(s);
    if (fracMatch != null) {
      final num = double.tryParse(fracMatch.group(1)!) ?? 0;
      final den = double.tryParse(fracMatch.group(2)!) ?? 1;
      return num / den;
    }

    // 5. Clean Numeric Fallback (extracts first number found)
    final numMatch = RegExp(r'(\d+\.?\d*)').firstMatch(s);
    if (numMatch != null) {
      return double.tryParse(numMatch.group(1)!) ?? fallback;
    }

    return fallback;
  }

  factory IngredientItem.fromJson(Map<String, dynamic> json) {
    String name = (json['name'] ?? json['ingredient'] ?? "").toString();
    double quantity = toDouble(json['quantity'] ?? json['quantiy'], fallback: 0.0);
    String unit = (json['unit'] ?? "").toString().trim().toLowerCase();
    double? calories = json['calories'] != null ? toDouble(json['calories']) : null;

    // SMART REPAIR:
    // Pattern 1: Truncated "l" (large/lemon) or "g" or "c"
    if ((unit == "l" || unit == "g" || unit == "c") && name.isNotEmpty) {
      String lowName = name.toLowerCase();
      // If name starts with "arge" or "agre" and unit is "l" -> large
      if (unit == "l" && (lowName.startsWith("arge") || lowName.startsWith("agre"))) {
         name = "large" + name.substring(4);
         unit = "";
      } else if (unit == "l" && (lowName.startsWith("emon") || lowName.startsWith("mon"))) {
         name = "lemon" + (lowName.startsWith("emon") ? name.substring(4) : name.substring(3));
         unit = "";
      }
    }

    // Pattern 2: Missing first letter in common units/adjectives
    String lowName = name.toLowerCase();
    if (lowName.startsWith("ablespoon")) name = "t" + name;
    else if (lowName.startsWith("easpoon")) name = "t" + name;
    else if (lowName.startsWith("unces")) name = "o" + name;
    else if (lowName.startsWith("arge ") || lowName.startsWith("agre ")) name = "l" + name;
    else if (lowName.startsWith("emon ")) name = "l" + name;
    else if (lowName.startsWith("nion")) name = "o" + name;
    else if (lowName.startsWith("otato")) name = "p" + name;

    // Pattern 3: If quantity is 0, try to re-parse the whole thing
    if (quantity == 0) {
      final combined = unit.isEmpty ? name : "$unit $name";
      final smartParsed = Recipe.parseIngredient(combined);
      if (smartParsed != null && smartParsed.quantity > 0) {
        return smartParsed;
      }
    }

    // Strip HTML tags if any
    name = name.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    unit = unit.replaceAll(RegExp(r'<[^>]*>'), '').trim();

    final rawQty = (json['quantity'] ?? json['quantiy'])?.toString();
    final bool isComplex = rawQty != null && (rawQty.contains('/') || rawQty.contains('-'));

    return IngredientItem(
      name: name,
      quantity: quantity == 0 ? 1.0 : quantity,
      displayQuantity: json['displayQuantity'] ?? (isComplex ? rawQty : null), 
      unit: unit,
      calories: calories,
    );
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
