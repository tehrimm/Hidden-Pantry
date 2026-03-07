import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

class RecipeMatcher {
  // Simple mapping of ingredient names to "rarity" weights (simulated TF-IDF).
  // Higher values mean the ingredient is more unique/rare.
  static const Map<String, double> _ingredientWeights = {
    'chicken': 1.5,
    'beef': 1.5,
    'salmon': 2.0,
    'saffron': 3.0,
    'salt': 0.1,
    'water': 0.1,
    'flour': 0.5,
    'sugar': 0.5,
    'onion': 0.8,
    'garlic': 0.8,
  };

  static final Map<String, Set<String>> _allergenSynonyms = {
    'egg': {'egg', 'eggs', 'yolk', 'egg yolk', 'egg white', 'egg whites', 'albumen','scrambled eggs','century egg','duck egg','egg powder','egg white powder','fresh eggs','Egg'},
    'dairy': {'milk', 'dairy', 'cheese', 'butter', 'cream', 'yogurt', 'parmesan', 'parmasean', 'mozzarella', 'cheddar', 'ricotta', 'whey', 'lactose', 'casein', 'ghee', 'buttermilk'},
    'peanut': {'peanut', 'peanuts', 'groundnut'},
    'soy': {'soy', 'soya', 'soybean', 'soybeans', 'tofu'},
    'wheat': {'wheat', 'flour', 'bread', 'gluten'},
    'gluten': {'gluten', 'wheat', 'flour', 'bread'},
    'fish': {'fish', 'salmon', 'tuna', 'cod', 'trout', 'mackerel'},
    'shellfish': {'shellfish', 'shrimp', 'prawn', 'lobster', 'crab', 'scallop'},
    'tree nut': {'tree nut', 'almond', 'walnut', 'cashew', 'hazelnut', 'pecan', 'pistachio'},
    'tomatoes': {'tomato', 'tomatoes', 'ketchup', 'marinara', 'salsa', 'passata'},
    'spicy': {'spicy', 'chili', 'chilli', 'pepper', 'jalapeno', 'cayenne', 'paprika', 'sriracha', 'harissa', 'chili powder', 'chilli powder', 'hot sauce'},
    'caffeine': {'caffeine', 'coffee', 'espresso', 'tea', 'black tea', 'green tea', 'matcha', 'cola', 'energy drink', 'guarana'},
  };

  static final Set<String> _stopWords = {
    'fresh',
    'organic',
    'large',
    'medium',
    'small',
    'free',
    'range',
    'free-range',
    'extra',
    'extra-large',
    'grade',
  };

  // Normalizes an ingredient name for comparison:
  // lowercase, trim, and basic stemming (trailing 's', 'es').
  static String normalize(String name) {
    String s = name.toLowerCase().trim();
    if (s.endsWith('es')) {
      s = s.substring(0, s.length - 2);
    } else if (s.endsWith('s') && !s.endsWith('ss')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  static Set<String> _tokens(String name) {
    final lower = name.toLowerCase();
    final cleaned = lower.replaceAll(RegExp(r'[^a-z ]'), ' ');
    final parts = cleaned.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).map(normalize);
    return parts.where((e) => !_stopWords.contains(e)).toSet();
  }

  static Set<String> _synsFor(String allergen) {
    final a = normalize(allergen);
    final base = {a, '$a' 's'};
    final extra = _allergenSynonyms[a] ?? {};
    return {...base, ...extra}.map(normalize).toSet();
  }

  static bool _containsAllergen(String ingredient, Set<String> allergens) {
    final toks = _tokens(ingredient);
    for (final a in allergens) {
      final syns = _synsFor(a);
      for (final s in syns) {
        if (toks.contains(s)) return true;
        if (ingredient.toLowerCase().contains(s)) return true;
      }
    }
    return false;
  }

  // Checks if an ingredient matches any in the pantry, using normalization.
  static bool isMatch(String recipeIng, List<String> pantry) {
    final normRecipeIng = normalize(recipeIng);
    return pantry.any((p) => normalize(p) == normRecipeIng);
  }

  // Determines the weight of an ingredient. 
  // Defaults to 1.0 if not in predefined rarity list.
  static double getWeight(String ingredient) {
    final norm = normalize(ingredient);
    return _ingredientWeights[norm] ?? 1.0;
  }

  /// Calculates a match percentage (0.0 to 1.0).
  /// Handles allergies, weighting, and missing core ingredients.
  static double calculateMatch(
    Recipe recipe,
    List<String> pantry, {
    List<String> allergies = const [],
  }) {
    if (pantry.isEmpty) return 0.0;
    if (recipe.ingredients.isEmpty) return 0.0;

    final normPantry = pantry.map(normalize).toSet();
    final normAllergies = allergies.map(normalize).toSet();

    double totalWeight = 0.0;
    double matchedWeight = 0.0;

    for (final ing in recipe.ingredients) {
      final name = ing.name;
      final normName = normalize(name);

      // Rule : Exclude Allergens
      if (normAllergies.contains(normName) || _containsAllergen(name, normAllergies)) {
        return 0.0;
      }

      final weight = getWeight(name);
      totalWeight += weight;

      if (normPantry.contains(normName)) {
        matchedWeight += weight;
      }
    }

    if (totalWeight == 0) return 0.0;
    return matchedWeight / totalWeight;
  }

  /// Sorts a list of recipes by match percentage, then by tie-breakers.
  static List<Recipe> sortRecipesByMatch(
    List<Recipe> recipes,
    List<String> pantry, {
    List<String> allergies = const [],
  }) {
    final List<MapEntry<Recipe, double>> scores = recipes.map((r) {
      return MapEntry(r, calculateMatch(r, pantry, allergies: allergies));
    }).toList();

    scores.sort((a, b) {
      // Primary: Match percentage descending
      int cmp = b.value.compareTo(a.value);
      if (cmp != 0) return cmp;

      // Rule : Tie-breaker sorting (Rating descending, then Total Time ascending)
      int ratingCmp = b.key.avgRating.compareTo(a.key.avgRating);
      if (ratingCmp != 0) return ratingCmp;

      return a.key.minutes.compareTo(b.key.minutes);
    });

    return scores.map((e) => e.key).toList();
  }
}
