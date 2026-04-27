import 'package:flutter/material.dart' as material;

class IngredientIconMapper {
  static material.IconData getIcon(String ingredientName) {
    final name = ingredientName.toLowerCase();
    
    // ============ ALCOHOLIC BEVERAGES ============
    if (_containsAny(name, [
      'wine', 'beer', 'vodka', 'rum', 'whisky', 'gin', 'tequila', 'brandy',
      'liqueur', 'sake', 'vermouth', 'cider', 'champagne', 'cocktail',
      'bourbon', 'cognac', 'schnapps', 'grappa', 'liquor', 'ale', 'stout',
      'sangria', 'moonshine', 'cachaça', 'aperol', 'limoncello', 'amaretto',
      'bitters', 'curacao', 'drambuie', 'irish cream', 'port wine',
      'absinthe', 'advocaat', 'sloe gin', 'pisco', 'mezcal', 'kirsch',
      'marsala wine', 'madeira wine', 'sherry', 'vermouth', 'genever'
    ])) {
      return material.Icons.local_bar_outlined;
    }

    // ============ BEVERAGES (non-alcoholic) ============
    if (_containsAny(name, [
      'water', 'juice', 'soda', 'coffee', 'tea', 'broth', 'stock',
      'soup', 'drink', 'beverage', 'smoothie', 'milkshake', 'lemonade',
      'iced tea', 'kombucha', 'energy drink', 'sports drink', 'tonic water',
      'seltzer', 'sparkling water', 'mineral water', 'coconut water',
      'chai', 'matcha'
    ])) {
      return material.Icons.local_cafe_outlined;
    }

    // ============ OILS & VINEGARS ============
    // Higher priority than fruits/vegetables to catch 'olive oil' or 'chili oil'
    if (_containsAny(name, [
      'oil', 'vinegar', 'olive oil', 'coconut oil', 'sesame oil', 'vegetable oil',
      'canola oil', 'avocado oil', 'grapeseed oil', 'palm oil', 'truffle oil',
      'balsamic', 'rice vinegar', 'apple cider vinegar', 'red wine vinegar',
      'white vinegar', 'cooking spray', 'ghee', 'lard', 'tallow', 'duck fat'
    ])) {
      return material.Icons.opacity_outlined;
    }

    // ============ SAUCES & CONDIMENTS ============
    // Higher priority to catch 'soy sauce', 'tomato sauce' etc.
    if (_containsAny(name, [
      'sauce', 'dressing', 'condiment', 'ketchup', 'mustard', 'mayonnaise',
      'relish', 'chutney', 'salsa', 'pesto', 'tahini', 'soy sauce',
      'teriyaki', 'hoisin', 'sriracha', 'hot sauce', 'bbq sauce', 'steak sauce',
      'tartar', 'cocktail sauce', 'marinara', 'alfredo', 'gravy', 'jus',
      'vinaigrette', 'aioli', 'remoulade', 'tapenade', 'mayo', 'miracle whip',
      'hummus', 'guacamole', 'miso', 'tamari', 'ponzu'
    ])) {
      return material.Icons.science_outlined;
    }

    // ============ SPICES, SALT & SEASONINGS ============
    // Note: 'clove' removed to avoid matching 'garlic cloves'; 'whole clove' used instead.
    if (_containsAny(name, [
      'spice', 'salt', 'pepper', 'cinnamon', 'ginger', 'herb', 'parsley',
      'basil', 'thyme', 'oregano', 'rosemary', 'mint', 'cilantro', 'dill',
      'sage', 'bay leaf', 'paprika', 'cumin', 'coriander', 'turmeric',
      'cardamom', 'whole clove', 'nutmeg', 'star anise', 'fennel seed', 'mustard seed',
      'vanilla', 'anise', 'caraway', 'juniper', 'wasabi', 'horseradish',
      'chili powder', 'garlic powder', 'onion powder', 'furikake', 'togarashi',
      'msg', 'seasoning', 'rub'
    ])) {
      return material.Icons.restaurant_menu_outlined;
    }

    // ============ MEAT & POULTRY ============
    if (_containsAny(name, [
      'chicken', 'turkey', 'duck', 'goose', 'poultry', 'breast', 'wing', 'thigh',
      'beef', 'steak', 'pork', 'lamb', 'mutton', 'veal', 'bacon', 'ham',
      'sausage', 'chorizo', 'pepperoni', 'salami', 'pastrami', 'prosciutto',
      'ground beef', 'ground pork', 'burger patty', 'hot dog'
    ])) {
      return material.Icons.food_bank_outlined;
    }
    
    // ============ SEAFOOD ============
    if (_containsAny(name, [
      'fish', 'salmon', 'tuna', 'shrimp', 'prawn', 'seafood', 'crab', 'lobster',
      'cod', 'bass', 'trout', 'mackerel', 'sardine', 'anchovy', 'clam',
      'oyster', 'mussel', 'scallop', 'squid', 'octopus', 'caviar', 'roe'
    ])) {
      return material.Icons.emoji_food_beverage_outlined;
    }

    // ============ VEGETABLES ============
    if (_containsAny(name, [
      'lettuce', 'veg', 'mushroom', 'cucumber', 'corn', 'garlic', 'onion',
      'kale', 'cabbage', 'asparagus', 'zucchini', 'cauliflower', 'celery', 'broccoli',
      'eggplant', 'pumpkin', 'squash', 'radish', 'beetroot', 'turnip',
      'parsnip', 'artichoke', 'okra', 'leek', 'shallot', 'scallion', 'spinach',
      'fennel', 'rhubarb', 'horseradish', 'capers', 'bell pepper', 'chive'
    ])) {
      return material.Icons.eco_outlined;
    }

    // ============ FRUITS ============
    if (_containsAny(name, [
      'apple', 'banana', 'berry', 'berries', 'strawberr', 'blueberr', 'grape',
      'orange', 'lemon', 'lime', 'fruit', 'mango', 'peach', 'pineapple',
      'cherry', 'cherri', 'pear', 'watermelon', 'melon', 'apricot', 'plum', 'nectarine',
      'kiwi', 'papaya', 'guava', 'fig', 'date', 'raisin', 'prune', 'cranberr',
      'raspberr', 'blackberr', 'avocado', 'olive', 'coconut', 'pomegranate',
      'grapefruit', 'tangerine', 'clementine', 'persimmon', 'plantain'
    ])) {
      return material.Icons.forest_outlined;
    }

    // ============ DAIRY & EGGS ============
    if (_containsAny(name, ['egg', 'eggs', 'egg white', 'egg yolk'])) {
      return material.Icons.egg_outlined;
    }
    if (_containsAny(name, [
      'milk', 'cheese', 'butter', 'cream', 'yogurt', 'dairy', 'curd',
      'kefir', 'whey', 'casein', 'creme fraiche', 'buttermilk', 'paneer',
      'ricotta', 'mozzarella', 'cheddar', 'parmesan', 'feta', 'sour cream'
    ])) {
      return material.Icons.egg_alt_outlined;
    }
    
    // ============ GRAINS, BREAD & PASTA ============
    if (_containsAny(name, [
      'rice', 'pasta', 'bread', 'flour', 'wheat', 'grain', 'noodle',
      'quinoa', 'oats', 'cereal', 'dough', 'spaghetti', 'semolina',
      'barley', 'millet', 'rye', 'cornmeal', 'couscous', 'bulgur',
      'tortilla', 'pita', 'naan', 'bagel', 'bun', 'roll', 'sourdough'
    ])) {
      return material.Icons.bakery_dining_outlined;
    }
    
    // ============ NUTS & SEEDS ============
    if (_containsAny(name, [
      'nut', 'almond', 'peanut', 'cashew', 'walnut', 'pecan', 'pistachio',
      'hazelnut', 'macadamia', 'seed', 'chia', 'flax', 'hemp', 'sesame',
      'pumpkin seed', 'sunflower seed', 'pine nut'
    ])) {
      return material.Icons.nature_outlined;
    }
    
    // ============ SWEETENERS ============
    if (_containsAny(name, [
      'sugar', 'honey', 'maple syrup', 'agave', 'stevia', 'sweetener',
      'molasses', 'corn syrup', 'brown sugar', 'powdered sugar'
    ])) {
      return material.Icons.cookie_outlined;
    }
    
    // ============ MUSHROOMS & FUNGI ============
    if (_containsAny(name, [
      'mushroom', 'fungus', 'shiitake', 'maitake', 'enoki', 'oyster mushroom',
      'portobello', 'cremini', 'button mushroom', 'porcini', 'morel', 'chanterelle'
    ])) {
      return material.Icons.grass_outlined;
    }

    // ============ LEGUMES & PLANT PROTEINS ============
    if (_containsAny(name, [
      'bean', 'lentil', 'chickpea', 'legume', 'pea', 'edamame', 'soybean',
      'tofu', 'tempeh', 'seitan', 'black bean', 'kidney bean', 'pinto bean',
      'navy bean', 'lima bean', 'fava bean', 'split pea', 'dal', 'dhal'
    ])) {
      return material.Icons.grain_outlined;
    }

    // ============ DESSERTS & BAKED GOODS ============
    if (_containsAny(name, [
      'cake', 'brownie', 'cookie', 'dessert', 'muffin', 'pastry', 'tart',
      'pudding', 'custard', 'fudge', 'candy', 'candy bar', 'confection',
      'frosting', 'icing', 'ganache', 'tiramisu', 'cheesecake'
    ])) {
      return material.Icons.cake_outlined;
    }

    // ============ FROZEN FOODS ============
    if (_containsAny(name, [
      'frozen', 'ice cream', 'gelato', 'sorbet', 'popsicle', 'frozen yogurt'
    ])) {
      return material.Icons.ac_unit_outlined;
    }

    // ============ SEA VEGETABLES & ALGAE ============
    if (_containsAny(name, [
      'seaweed', 'kelp', 'nori', 'dulse', 'wakame', 'kombu', 'arame', 'hijiki'
    ])) {
      return material.Icons.waves_outlined;
    }

    // ============ SNACKS & PROCESSED FOODS ============
    if (_containsAny(name, [
      'chip', 'crisp', 'pretzel', 'popcorn', 'cracker', 'snack', 'jerky',
      'granola bar', 'trail mix', 'rice cake', 'pork rind'
    ])) {
      return material.Icons.fastfood_outlined;
    }

    // ============ PLANT-BASED / VEGAN MEAT ============
    if (_containsAny(name, [
      'vegan', 'veggie burger', 'plant-based', 'impossible', 'beyond meat',
      'meatless', 'meat substitute', 'soy protein', 'textured vegetable'
    ])) {
      return material.Icons.spa_outlined;
    }

    // ============ HEALTH SUPPLEMENTS ============
    if (_containsAny(name, [
      'supplement', 'protein powder', 'superfood', 'collagen', 'probiotic',
      'vitamin', 'mineral', 'omega', 'spirulina', 'wheatgrass', 'reishi',
      'ashwagandha', 'turmeric supplement', 'elderberry', 'prebiotic',
      'electrolyte', 'creatine', 'bcaa', 'multivitamin',
      'formula', 'infant formula', 'baby food', 'baby formula'
    ])) {
      return material.Icons.medication_outlined;
    }

    // ============ PICKLED & PRESERVED ============
    if (_containsAny(name, [
      'pickled', 'pickle', 'fermented', 'kimchi', 'sauerkraut',
      'preserved', 'marinated', 'cured'
    ])) {
      return material.Icons.science_outlined;
    }

    // ============ DRIED / DEHYDRATED ============
    if (_containsAny(name, [
      'dried', 'dehydrated', 'sun-dried'
    ])) {
      return material.Icons.wb_sunny_outlined;
    }

    // ============ DEFAULT - PANTRY ============
    return material.Icons.kitchen_outlined;
  }
  
  static bool _containsAny(String text, List<String> keywords) {
    for (final word in keywords) {
      if (text.contains(word)) return true;
    }
    return false;
  }
}