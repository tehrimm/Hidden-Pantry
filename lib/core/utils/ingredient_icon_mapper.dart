import 'package:flutter/material.dart';

class IngredientIconMapper {
  static IconData getIcon(String ingredientName) {
    final name = ingredientName.toLowerCase();
    
    // ============ BEVERAGES (non-alcoholic) ============
    if (_containsAny(name, [
      'water', 'juice', 'soda', 'coffee', 'tea', 'broth', 'stock',
      'soup', 'drink', 'beverage', 'smoothie', 'milkshake', 'lemonade',
      'iced tea', 'kombucha', 'energy drink', 'sports drink', 'tonic water',
      'seltzer', 'sparkling water', 'mineral water', 'coconut water',
      'chai', 'matcha', 'rooibos', 'herbal tea', 'chicory coffee',
      'frappé', 'protein drink', 'clamato', 'v8 juice', 'verjuice',
      'water kefir', 'kool aid', 'root beer', 'ginger ale', 'ginger beer',
      'cream soda', 'dr pepper', 'coke', 'sprite', 'mountain dew',
      'lime soda', 'orange soda', 'cherry soda', 'grape soda',
      'lemon lime soda', 'piña colada mix', 'daiquiri mix', 'margarita mix',
      'bloody mary mix', 'carnation breakfast essentials'
    ])) {
      return Icons.local_cafe_outlined;
    }
    
    // ============ ALCOHOLIC BEVERAGES ============
    if (_containsAny(name, [
      'wine', 'beer', 'vodka', 'rum', 'whisky', 'gin', 'tequila', 'brandy',
      'liqueur', 'sake', 'vermouth', 'cider', 'champagne', 'cocktail',
      'bourbon', 'cognac', 'schnapps', 'grappa', 'liquor', 'ale', 'stout',
      'sangria', 'moonshine', 'cachaça', 'aperol', 'limoncello', 'amaretto',
      'bitters', 'curacao', 'drambuie', 'irish cream', 'port wine',
      'absinthe', 'advocaat', 'sloe gin', 'pisco', 'mezcal', 'kirsch',
      'marsala wine', 'madeira wine', 'sherry', 'vermouth', 'genever',
      'galliano', 'gentian liqueur', 'herbal liqueur', 'elderflower liqueur',
      'melon liqueur', 'strawberry liqueur', 'raspberry liqueur',
      'peach liqueur', 'banana liqueur', 'coconut rum', 'gold rum',
      'white rum', 'sparkling wine', 'rosé wine', 'red wine', 'white wine',
      'cooking wine', 'cream sherry', 'dry vermouth', 'pumpkin ale'
    ])) {
      return Icons.local_bar_outlined;
    }
    
    // ============ MEAT & POULTRY ============
    if (_containsAny(name, [
      'chicken', 'turkey', 'duck', 'goose', 'poultry', 'breast', 'wing', 'thigh',
      'beef', 'steak', 'pork', 'lamb', 'mutton', 'veal', 'bacon', 'ham',
      'sausage', 'chorizo', 'pepperoni', 'salami', 'pastrami', 'prosciutto',
      'ground beef', 'ground pork', 'burger patty', 'hot dog', 'kielbasa',
      'andouille', 'guanciale', 'pancetta', 'foie gras', 'venison', 'bison',
      'rabbit', 'quail', 'pheasant', 'ostrich', 'oxtail', 'blood sausage',
      'capon', 'cornish hen', 'grouse', 'guinea fowl', 'pigeon', 'quail',
      'roast beef', 'roast duck', 'rotisserie chicken', 'pulled chicken',
      'pulled pork', 'pulled turkey', 'smoked chicken', 'smoked turkey',
      'turkey bacon', 'turkey sausage', 'chicken sausage', 'chicken andouille',
      'chicken chorizo', 'chicken hot dog', 'chicken salami', 'deli chicken',
      'deli ham', 'deli turkey', 'canadian bacon', 'country ham', 'serrano ham',
      'black forest ham', 'smoked ham hock', 'bacon bits', 'bacon lardons',
      'bacon jam', 'liver spread', 'deviled ham spread', 'chicken liver',
      'turkey liver', 'duck liver', 'beef liver', 'chicken gizzards',
      'turkey gizzards', 'duck gizzards', 'chicken feet', 'chicken necks',
      'turkey neck', 'chicken backs', 'turkey wings', 'chicken wings',
      'chicken leg', 'chicken thigh', 'chicken quarter', 'whole chicken',
      'whole turkey', 'young chicken', 'chicken tenders', 'chicken patty',
      'chicken nuggets', 'popcorn chicken', 'chicken schnitzel'
    ])) {
      return Icons.food_bank_outlined;
    }
    
    // ============ SEAFOOD ============
    if (_containsAny(name, [
      'fish', 'salmon', 'tuna', 'shrimp', 'prawn', 'seafood', 'crab', 'lobster',
      'cod', 'bass', 'trout', 'mackerel', 'sardine', 'anchovy', 'clam',
      'oyster', 'mussel', 'scallop', 'squid', 'octopus', 'caviar', 'roe',
      'eel', 'herring', 'haddock', 'halibut', 'tilapia', 'catfish', 'crawfish',
      'abalone', 'pollock', 'cuttlefish', 'sea urchin', 'surimi', 'bottarga',
      'anchovy paste', 'fish sauce', 'bonito', 'dried shrimp', 'lox', 'gravlax',
      'barnacle', 'barramundi', 'branzino', 'flounder', 'grouper', 'mahi mahi',
      'monkfish', 'perch', 'pike', 'pomfret', 'pompano', 'rockfish', 'snapper',
      'sole', 'sturgeon', 'swordfish', 'tilapia', 'trout', 'turbot', 'whitefish',
      'whiting', 'yellowtail', 'arctic char', 'black cod', 'bluefish', 'coho salmon',
      'kingfish', 'ocean perch', 'pollock', 'rainbow trout', 'red mullet',
      'sockeye salmon', 'steelhead trout', 'walleye', 'canned tuna', 'canned salmon',
      'canned sardines', 'canned crab', 'canned clam', 'smoked salmon', 'smoked trout',
      'smoked mackerel', 'smoked eel', 'smoked herring', 'smoked fish',
      'salt cod', 'salt fish', 'salt herring', 'dried fish', 'fish balls',
      'fish cake', 'korean fish cake', 'fish fillets', 'fish heads',
      'fish pie mix', 'surimi', 'tarama', 'caviar', 'bottarga', 'fish oil'
    ])) {
      return Icons.emoji_food_beverage_outlined;
    }
    
    // ============ VEGETABLES ============
    if (_containsAny(name, [
      'onion', 'garlic', 'tomato', 'potato', 'carrot', 'broccoli', 'spinach',
      'lettuce', 'veg', 'mushroom', 'pepper', 'chili', 'cucumber', 'corn',
      'kale', 'cabbage', 'asparagus', 'zucchini', 'cauliflower', 'celery',
      'eggplant', 'pumpkin', 'squash', 'radish', 'beetroot', 'turnip',
      'parsnip', 'artichoke', 'okra', 'leek', 'shallot', 'scallion',
      'fennel', 'rhubarb', 'horseradish', 'capers', 'daikon', 'jicama',
      'napa cabbage', 'bok choy', 'microgreens', 'sprouts', 'watercress',
      'arugula', 'endive', 'frisee', 'radicchio', 'chicory', 'belgian endive',
      'collard greens', 'mustard greens', 'turnip greens', 'beet greens',
      'chard', 'lacinato kale', 'callaloo', 'broccoli rabe', 'broccolini',
      'brussels sprout', 'kohlrabi', 'celeriac', 'jerusalem artichoke',
      'sunchoke', 'taro', 'yam', 'cassava', 'jicama', 'water chestnut',
      'lotus root', 'bamboo shoot', 'hearts of palm', 'palm heart',
      'sugar pumpkin', 'butternut squash', 'acorn squash', 'delicata squash',
      'spaghetti squash', 'kabocha squash', 'pattypan squash', 'zucchini',
      'cucumber', 'pickle', 'okra', 'peas', 'green beans', 'snap peas',
      'snow peas', 'fava beans', 'lima beans', 'edamame', 'pea shoots',
      'bean sprouts', 'alfalfa sprouts', 'broccoli sprouts', 'sunflower sprouts',
      'garlic scapes', 'ramps', 'wild leek', 'fiddlehead', 'nopales',
      'cactus paddle', 'tomatillo', 'green tomato', 'cherry tomato',
      'grape tomato', 'roma tomato', 'heirloom tomato', 'red onion',
      'yellow onion', 'white onion', 'sweet onion', 'pearl onion', 'shallot',
      'scallion', 'leek', 'chive', 'garlic chive', 'celery stalk', 'celery root',
      'fennel bulb', 'rhubarb stalk'
    ])) {
      return Icons.eco_outlined;
    }
    
    // ============ FRUITS ============
    if (_containsAny(name, [
      'apple', 'banana', 'berry', 'strawberry', 'blueberry', 'grape',
      'orange', 'lemon', 'lime', 'fruit', 'mango', 'peach', 'pineapple',
      'cherry', 'pear', 'watermelon', 'melon', 'apricot', 'plum', 'nectarine',
      'kiwi', 'papaya', 'guava', 'lychee', 'dragon fruit', 'passion fruit',
      'fig', 'date', 'raisin', 'prune', 'cranberry', 'raspberry', 'blackberry',
      'currant', 'gooseberry', 'avocado', 'olive', 'coconut', 'pomegranate',
      'grapefruit', 'tangerine', 'clementine', 'persimmon', 'quince', 'jackfruit',
      'durian', 'rambutan', 'longan', 'star fruit', 'plantain', 'acai', 'goji',
      'elderberry', 'lingonberry', 'huckleberry', 'boysenberry', 'cloudberry',
      'feijoa', 'tamarind', 'soursop', 'cherimoya', 'custard-apple', 'sapote',
      'mamey', 'cantaloupe', 'honeydew', 'casaba melon', 'canary melon',
      'asian pear', 'bosc pear', 'anjou pear', 'bartlett pear', 'fuji apple',
      'gala apple', 'granny smith', 'honeycrisp', 'red delicious', 'golden delicious',
      'ambrosia apple', 'crabapple', 'sour cherry', 'sweet cherry', 'bing cherry',
      'rainier cherry', 'red grape', 'green grape', 'concord grape', 'muscat grape',
      'blood orange', 'navel orange', 'valencia orange', 'mandarin', 'satsuma',
      'tangelo', 'pomelo', 'kumquat', 'calamansi', 'key lime', 'meyer lemon',
      'finger lime', 'kaffir lime', 'amla', 'aronia berry', 'barberry', 'chikoo',
      'haskap berry', 'hawthorn', 'java plum', 'jujube', 'kokum', 'loganberry',
      'mulberry', 'oregon grape', 'physalis', 'prickly pear', 'rosehip',
      'saskatoon berry', 'sea buckthorn', 'sloe berry', 'wood apple', 'yuzu',
      'citron', 'grape', 'currant', 'gooseberry', 'lingonberry'
    ])) {
      return Icons.forest_outlined;
    }
    
    // ============ NUTS & SEEDS ============
    if (_containsAny(name, [
      'nut', 'almond', 'peanut', 'cashew', 'walnut', 'pecan', 'pistachio',
      'hazelnut', 'macadamia', 'chestnut', 'seed', 'chia', 'flax', 'hemp',
      'sesame seed', 'pumpkin seed', 'sunflower seed', 'poppy seed', 'pine nut',
      'cacao nib', 'candlenut', 'ginkgo', 'lotus seed', 'tigernut', 'barùkas',
      'brazil nut', 'chironji', 'indian almond', 'jackfruit seed', 'melon seed',
      'palm seed', 'pine cone', 'watermelon seed', 'apricot kernel',
      'bitter almond', 'candied walnut', 'honey-roasted almond', 'honey-roasted cashew',
      'honey-roasted peanut', 'honey-roasted pecan', 'roasted almond',
      'roasted peanut', 'slivered almond', 'smoked almond', 'sriracha almond',
      'toasted nut', 'chestnut', 'ginkgo nut', 'lotus seed', 'pumpkin seed',
      'sunflower seed', 'chia seed', 'flaxseed', 'hemp heart', 'poppy seed',
      'sesame seed', 'nigella seed', 'caraway seed', 'celery seed', 'fennel seed',
      'mustard seed', 'coriander seed', 'cumin seed', 'aniseed', 'fenugreek seed'
    ])) {
      return Icons.nature_outlined;
    }
    
    // ============ DAIRY & EGGS ============
    if (_containsAny(name, ['egg', 'eggs', 'egg white', 'egg yolk', 'salted egg', 'pickled egg', 'century egg', 'quail egg', 'duck egg'])) {
      return Icons.egg_outlined;
    }
    if (_containsAny(name, [
      'milk', 'cheese', 'butter', 'cream', 'yogurt', 'dairy', 'curd', 'ghee',
      'kefir', 'whey', 'casein', 'creme fraiche', 'buttermilk', 'half and half',
      'paneer', 'ricotta', 'mozzarella', 'cheddar', 'parmesan', 'feta',
      'brie', 'camembert', 'gouda', 'swiss', 'provolone', 'havarti',
      'monterey jack', 'colby', 'fromage', 'queso', 'labneh', 'mascarpone',
      'cream cheese', 'cottage cheese', 'string cheese', 'babybel', 'asiago',
      'fontina', 'gruyere', 'manchego', 'pecorino', 'romano', 'stilton',
      'blue cheese', 'gorgonzola', 'roquefort', 'goat cheese', 'sheep cheese',
      'buffalo milk', 'evaporated milk', 'condensed milk', 'powdered milk',
      'soy milk', 'almond milk', 'oat milk', 'rice milk', 'coconut milk',
      'hemp milk', 'flax milk', 'cashew milk', 'non-dairy milk', 'lactaid milk',
      'raw milk', 'sour cream', 'clotted cream', 'double cream', 'heavy cream',
      'whipped cream', 'creamer', 'coffee creamer', 'yogurt', 'greek yogurt',
      'skyr', 'kefir', 'lassi', 'dahi', 'hung curd', 'khoya', 'chenna',
      'quark', 'tvorog', 'fromage blanc', 'ricotta', 'mascarpone', 'marscapone',
      'vegan butter', 'vegan cheese', 'vegan cream cheese', 'vegan sour cream',
      'vegan yogurt', 'soy-free butter', 'coconut yogurt', 'almond yogurt',
      'cashew yogurt', 'coconut kefir', 'goat kefir', 'sheep milk yogurt'
    ])) {
      return Icons.egg_alt_outlined;
    }
    
    // ============ GRAINS, BREAD & PASTA ============
    if (_containsAny(name, [
      'rice', 'pasta', 'bread', 'flour', 'wheat', 'grain', 'noodle',
      'quinoa', 'oats', 'cereal', 'dough', 'spaghetti', 'semolina',
      'barley', 'millet', 'rye', 'cornmeal', 'couscous', 'bulgur', 'farro',
      'freekeh', 'kamut', 'spelt', 'teff', 'amaranth', 'buckwheat', 'polenta',
      'hominy', 'grits', 'ramen', 'udon', 'soba', 'vermicelli', 'lasagna',
      'fettuccine', 'linguine', 'rigatoni', 'penne', 'macaroni', 'orzo',
      'acini di pepe', 'bucatini', 'campanelle', 'cannelloni', 'casarecce',
      'cavatelli', 'ditalini', 'fregola', 'gnocchi', 'kluski', 'mafalde',
      'manicotti', 'misua', 'orecchiette', 'paccheri', 'pappardelle', 'radiatore',
      'ravioli', 'rotelle', 'tagliatelle', 'tortellini', 'trottole', 'ziti',
      'angel hair', 'bow-tie pasta', 'spiral pasta', 'short-cut pasta',
      'soup pasta', 'pot pie noodle', 'soba noodle', 'somen noodle', 'udon noodle',
      'rice noodle', 'glass noodle', 'kelp noodle', 'shirataki noodle',
      'sweet potato noodle', 'quinoa pasta', 'brown rice pasta', 'black bean pasta',
      'gluten-free pasta', 'bean pasta', 'rice paper', 'wonton wrapper',
      'dumpling wrapper', 'egg roll wrapper', 'gyoza wrapper', 'phyllo', 'kataifi',
      'puff pastry', 'pie crust', 'pizza crust', 'tamale dough', 'masa dough',
      'bread dough', 'croissant dough', 'cinnamon roll dough', 'cookie dough',
      'biscuit dough', 'sourdough starter', 'sourdough discard', 'bagel',
      'bun', 'roll', 'brioche', 'ciabatta', 'focaccia', 'pita', 'naan',
      'tortilla', 'wrap', 'baguette', 'rye bread', 'whole wheat bread',
      'white bread', 'sourdough', 'multigrain bread', 'pumpernickel', 'biscuit',
      'muffin', 'scone', 'croissant', 'danish', 'bagel', 'english muffin',
      'biscotti', 'cracker', 'matzo', 'lady fingers', 'sponge cake',
      'angel food cake', 'ginger snaps', 'speculoos cookies', 'sandwich cookies'
    ])) {
      return Icons.bakery_dining_outlined;
    }
    
    // ============ LEGUMES & PULSES ============
    if (_containsAny(name, [
      'bean', 'lentil', 'pea', 'chickpea', 'garbanzo', 'dal', 'tofu',
      'soy', 'edamame', 'tempeh', 'miso', 'hummus', 'falafel', 'seitan',
      'black bean', 'kidney bean', 'pinto bean', 'navy bean', 'fava bean',
      'lima bean', 'mung bean', 'adzuki bean', 'urad dal', 'masoor dal',
      'chana', 'pigeon pea', 'cowpea', 'black-eyed pea', 'snow pea',
      'snap pea', 'split pea', 'soybean', 'cannellini', 'borlotti', 'flageolet',
      'gigantes', 'lupini', 'mayocoba', 'moth bean', 'scarlet runner',
      'winged bean', 'wax bean', 'yellow bean', 'pink bean', 'sugar bean',
      'field pea', 'horse gram', 'hyacinth bean', 'cluster bean', 'snake bean',
      'fava bean', 'chickpea', 'lentil', 'red lentil', 'green lentil',
      'brown lentil', 'black lentil', 'puy lentil', 'castelluccio lentil',
      'tofu', 'silken tofu', 'firm tofu', 'extra firm tofu', 'fried tofu',
      'deep-fried tofu', 'fermented tofu', 'smoked tofu', 'tofu skin',
      'tempeh', 'natto', 'seitan', 'soy curls', 'textured vegetable protein',
      'tvp', 'quorn', 'vegan chicken', 'vegan beef', 'vegan sausage',
      'vegan bacon', 'vegan pepperoni', 'vegan meatball', 'vegetarian hot dog'
    ])) {
      return Icons.forest_outlined;
    }
    
    // ============ SPICES, SALT & SEASONINGS ============
    if (_containsAny(name, [
      'spice', 'salt', 'pepper', 'cinnamon', 'ginger', 'herb', 'parsley',
      'basil', 'thyme', 'oregano', 'rosemary', 'mint', 'cilantro', 'dill',
      'sage', 'bay leaf', 'paprika', 'cumin', 'coriander', 'turmeric',
      'cardamom', 'clove', 'nutmeg', 'star anise', 'fennel seed', 'mustard seed',
      'fenugreek', 'curry', 'masala', 'cajun', 'zaatar', 'sumac', 'saffron',
      'vanilla', 'anise', 'caraway', 'juniper', 'wasabi', 'horseradish',
      'chili powder', 'garlic powder', 'onion powder', 'furikake', 'togarashi',
      'nutritional yeast', 'adobo', 'allspice', 'berbere', 'blackening',
      'chili-lime', 'chipotle', 'creole', 'dukkah', 'fajita', 'garam masala',
      'goda masala', 'harissa', 'herbes de provence', 'italian seasoning',
      'jerk', 'kitchen king', 'lemon & herb', 'meat masala', 'mexican seasoning',
      'mulling spices', 'mushroom seasoning', 'old bay', 'poultry seasoning',
      'pumpkin pie spice', 'ras el hanout', 'sambar powder', 'sazón',
      'seafood seasoning', 'shawarma', 'southwest seasoning', 'steak seasoning',
      'taco seasoning', 'tandoori', 'thai seasoning', 'salt-free seasoning',
      'seasoned salt', 'celtic salt', 'fleur de sel', 'hawaiian salt',
      'himalayan salt', 'kala namak', 'pickling salt', 'smoked salt',
      'truffle salt', 'vanilla salt', 'msg', 'mango powder', 'amchur',
      'lucuma powder', 'camu powder', 'banana powder', 'berry powder',
      'acai powder', 'carob powder', 'cinnamon sugar', 'apple pie spice',
      'bagel seasoning', 'baharat', 'biryani masala', 'chai masala',
      'chaat masala', 'chana masala', 'chili con carne seasoning', 'coffee rub',
      'coriander powder', 'cumin-coriander powder', 'curry powder',
      'ginger powder', 'mustard powder', 'onion powder', 'paprika', 'smoked paprika',
      'hot paprika', 'sweet paprika', 'pepper', 'black pepper', 'white pepper',
      'green peppercorn', 'pink peppercorn', 'cracked pepper', 'seasoned pepper',
      'red pepper flake', 'chili flake', 'calabrian pepper', 'arbol chile',
      'ancho chile powder', 'guajillo pepper', 'pasilla pepper', 'chipotle powder',
      'gochugaru', 'piri-piri', 'peri peri', 'sriracha seasoning', 'popcorn seasoning',
      'salad seasoning', 'pizza seasoning', 'togarashi', 'shichimi togarashi',
      'wasabi powder', 'horseradish powder', 'wasabi', 'ginger root', 'turmeric root',
      'horseradish', 'fresh herbs', 'dried herbs', 'bouquet garni', 'fines herbes'
    ])) {
      return Icons.restaurant_menu_outlined;
    }
    
    // ============ SAUCES, CONDIMENTS & SPREADS ============
    if (_containsAny(name, [
      'sauce', 'dressing', 'condiment', 'ketchup', 'mustard', 'mayonnaise',
      'relish', 'chutney', 'salsa', 'pesto', 'tahini', 'soy sauce',
      'teriyaki', 'hoisin', 'sriracha', 'hot sauce', 'bbq sauce', 'steak sauce',
      'tartar', 'cocktail sauce', 'marinara', 'alfredo', 'gravy', 'jus',
      'vinaigrette', 'aioli', 'remoulade', 'tapenade', 'jam', 'jelly', 'marmalade',
      'nutella', 'peanut butter', 'nut butter', 'spread', 'hummus', 'guacamole',
      'pico de gallo', 'salsa verde', 'enchilada sauce', 'taco sauce',
      'wing sauce', 'fish sauce', 'oyster sauce', 'hoisin sauce', 'plum sauce',
      'duck sauce', 'sweet and sour sauce', 'sweet chili sauce', 'thai sweet chili sauce',
      'chili sauce', 'chili crisp', 'chili paste', 'chili-garlic sauce',
      'sambal oelek', 'gochujang', 'doubanjiang', 'ssamjang', 'doenjang',
      'miso', 'white miso', 'yellow miso', 'red miso', 'brown miso',
      'ponzu', 'tamari', 'teriyaki', 'tonkatsu sauce', 'yum yum sauce',
      'yuzu kosho', 'chamoy', 'mole paste', 'tom yum paste', 'thai red curry paste',
      'panang curry', 'green curry', 'yellow curry', 'massaman curry',
      'harissa', 'chermoula', 'chimichurri', 'tzatziki', 'tahini', 'hummus',
      'baba ghanoush', 'muhammara', 'zhug', 'skhug', 'ajvar', 'lutenitsa',
      'pesto', 'red pesto', 'green pesto', 'sun-dried tomato pesto',
      'olive tapenade', 'tomato tapenade', 'olive paste', 'anchovy paste',
      'shrimp paste', 'fermented black bean paste', 'sweet bean paste',
      'sweet soybean paste', 'black bean sauce', 'black sesame paste',
      'sesame paste', 'tahini', 'cashew cheese sauce', 'cheese sauce',
      'cheddar sauce', 'béchamel sauce', 'hollandaise sauce', 'béarnaise sauce',
      'vodka sauce', 'bolognese sauce', 'carbonara sauce', 'alfredo sauce',
      'pizza sauce', 'pasta sauce', 'spaghetti sauce', 'marinara', 'arrabbiata',
      'puttanesca', 'amatriciana', 'ragù', 'curry sauce', 'butter chicken sauce',
      'tikka masala sauce', 'korma sauce', 'vindaloo sauce', 'jalfrezi sauce',
      'pad thai sauce', 'kung pao sauce', 'mongolian sauce', 'orange sauce',
      'lemon sauce', 'teriyaki sauce', 'yakitori sauce', 'unagi sauce', 'eel sauce',
      'mentsuyu', 'tentsuyu', 'dip', 'ranch dressing', 'blue cheese dressing',
      'caesar dressing', 'thousand island', 'russian dressing', 'french dressing',
      'italian dressing', 'greek vinaigrette', 'balsamic vinaigrette',
      'raspberry vinaigrette', 'lemon vinaigrette', 'lime vinaigrette',
      'sesame dressing', 'ginger dressing', 'carrot ginger dressing',
      'miso dressing', 'avocado-lime dressing', 'cilantro dressing',
      'chipotle aioli', 'garlic aioli', 'sriracha mayo', 'spicy mayo',
      'wasabi mayo', 'truffle aioli', 'aioli', 'mayonnaise', 'vegan mayonnaise',
      'japanese mayonnaise', 'kewpie', 'miracle whip', 'salad cream'
    ])) {
      return Icons.science_outlined;
    }
    
    // ============ OILS & VINEGARS ============
    if (_containsAny(name, [
      'oil', 'vinegar', 'olive oil', 'coconut oil', 'sesame oil', 'vegetable oil',
      'canola oil', 'avocado oil', 'grapeseed oil', 'palm oil', 'truffle oil',
      'balsamic', 'rice vinegar', 'apple cider vinegar', 'red wine vinegar',
      'white vinegar', 'cooking spray', 'extra virgin olive oil', 'virgin coconut oil',
      'toasted sesame oil', 'black sesame oil', 'chili oil', 'garlic oil',
      'ginger oil', 'wasabi oil', 'herb oil', 'basil oil', 'truffle oil',
      'walnut oil', 'pistachio oil', 'hazelnut oil', 'almond oil', 'macadamia oil',
      'avocado oil', 'flaxseed oil', 'hemp seed oil', 'pumpkin seed oil',
      'grape seed oil', 'sunflower oil', 'safflower oil', 'rice bran oil',
      'wheat germ oil', 'corn oil', 'soybean oil', 'peanut oil', 'mustard oil',
      'coconut oil', 'palm oil', 'red palm oil', 'shea butter', 'cocoa butter',
      'cacao butter', 'ghee', 'butter', 'margarine', 'shortening', 'lard', 'tallow',
      'schmaltz', 'duck fat', 'goose fat', 'beef fat', 'pork fat', 'chicken fat',
      'balsamic vinegar', 'white balsamic vinegar', 'champagne vinegar',
      'sherry vinegar', 'malt vinegar', 'distilled white vinegar', 'cleaning vinegar',
      'cane vinegar', 'coconut vinegar', 'date vinegar', 'fig balsamic',
      'honey vinegar', 'kombucha vinegar', 'lemon vinegar', 'lime vinegar',
      'moscatel vinegar', 'seasoned rice vinegar', 'spiced vinegar', 'sushi vinegar',
      'ume plum vinegar', 'white wine vinegar', 'red wine vinegar', 'apple cider vinegar',
      'rice wine vinegar', 'black vinegar', 'chinkiang vinegar', 'aged vinegar'
    ])) {
      return Icons.opacity_outlined;
    }
    
    // ============ SWEETENERS ============
    if (_containsAny(name, [
      'sugar', 'honey', 'maple syrup', 'agave', 'stevia', 'sweetener',
      'molasses', 'corn syrup', 'sucrose', 'fructose', 'glucose', 'maltose',
      'erythritol', 'xylitol', 'monk fruit', 'allulose', 'jaggery', 'treacle',
      'golden syrup', 'brown sugar', 'powdered sugar', 'confectioners sugar',
      'caster sugar', 'granulated sugar', 'raw sugar', 'turbinado sugar',
      'demerara sugar', 'muscovado sugar', 'palm sugar', 'coconut sugar',
      'date sugar', 'fruit sugar', 'icing sugar', 'sand sugar', 'coarse sugar',
      'black sugar', 'rock sugar', 'candy sugar', 'sugar syrup', 'simple syrup',
      'gum syrup', 'orgeat', 'grenadine', 'elderflower cordial', 'rose syrup',
      'lavender syrup', 'vanilla syrup', 'caramel syrup', 'butterscotch syrup',
      'chocolate syrup', 'strawberry syrup', 'raspberry syrup', 'blueberry syrup',
      'cherry syrup', 'cranberry syrup', 'pomegranate molasses', 'date syrup',
      'rice syrup', 'brown rice syrup', 'malt syrup', 'barley malt syrup',
      'yacon syrup', 'sorghum syrup', 'cane syrup', 'golden syrup', 'treacle',
      'black treacle', 'molasses', 'blackstrap molasses', 'honey', 'manuka honey',
      'clover honey', 'wildflower honey', 'orange blossom honey', 'creamed honey',
      'liquid stevia', 'monk fruit sweetener', 'sweet n low', 'equal', 'splenda',
      'sucralose', 'aspartame', 'saccharin', 'cannabis sugar', 'cinnamon sugar',
      'vanilla sugar', 'jam sugar', 'pectin sugar', 'preserving sugar'
    ])) {
      return Icons.cookie_outlined;
    }
    
    // ============ BAKING INGREDIENTS ============
    if (_containsAny(name, [
      'baking powder', 'baking soda', 'yeast', 'cornstarch', 'arrowroot',
      'gelatin', 'pectin', 'xanthan gum', 'baking mix', 'cake mix',
      'brownie mix', 'food coloring', 'extract', 'essence', 'sprinkles',
      'candy eyes', 'colored sugar', 'sanding sugar', 'baking chips',
      'chocolate chips', 'butterscotch chips', 'cinnamon chips', 'mint chips',
      'peanut butter chips', 'white baking chips', 'cocoa powder', 'baking cocoa',
      'dark cocoa', 'dutch-process cocoa', 'cacao powder', 'raw cacao powder',
      'activated charcoal', 'agar agar', 'almond extract', 'anise extract',
      'apple extract', 'banana extract', 'blueberry extract', 'butter extract',
      'caramel extract', 'cherry extract', 'chocolate extract', 'cinnamon extract',
      'coconut extract', 'corn extract', 'hazelnut extract', 'lemon extract',
      'lime extract', 'mango extract', 'maple extract', 'orange extract',
      'peppermint extract', 'pineapple extract', 'pistachio extract', 'raspberry extract',
      'root beer extract', 'rum extract', 'strawberry extract', 'tamarind extract',
      'ube flavoring', 'pandan extract', 'fiori di sicilia', 'kewra water',
      'orange blossom water', 'rose water', 'essence', 'vanilla', 'vanilla extract',
      'vanilla bean', 'vanilla paste', 'almond filling', 'poppyseed filling',
      'pie filling', 'lemon curd', 'lime curd', 'orange curd', 'passionfruit curd',
      'candied fruit', 'candied cherry', 'candied ginger', 'candied peel',
      'candied pineapple', 'crystallized ginger', 'maraschino cherry', 'mixed peel',
      'meringue powder', 'cream of tartar', 'liquid smoke', 'glycerine',
      'glucomannan', 'guar gum', 'locust bean gum', 'carrageenan', 'agar agar',
      'sodium alginate', 'calcium lactate', 'maltodextrin', 'soy lecithin',
      'sunflower lecithin', 'brewer\'s yeast', 'nutritional yeast', 'wine yeast',
      'champagne yeast', 'yeast extract', 'marmite', 'vegemite', 'bovril',
      'gravy browning', 'browning sauce', 'liquid aminos', 'coconut aminos',
      'tamari', 'soy sauce', 'tamarind paste', 'tomato paste', 'sun-dried tomato paste',
      'ginger paste', 'garlic paste', 'onion paste', 'chili paste', 'curry paste'
    ])) {
      return Icons.kitchen_outlined;
    }
    
    // ============ SWEETS, DESSERTS & CHOCOLATE ============
    if (_containsAny(name, [
      'chocolate', 'cocoa', 'cake', 'cookie', 'ice cream', 'snack',
      'candy', 'dessert', 'pudding', 'custard', 'mousse', 'brownie',
      'muffin', 'pastry', 'donut', 'croissant', 'pie', 'tart', 'cheesecake',
      'fudge', 'toffee', 'caramel', 'marshmallow', 'licorice', 'lollipop',
      'gum', 'sherbet', 'sorbet', 'gelato', 'frosting', 'icing', 'ganache',
      'marzipan', 'fondant', 'candy cane', 'candy corn', 'chocolate chip',
      'baking chocolate', 'couverture chocolate', 'milk chocolate', 'dark chocolate',
      'white chocolate', 'mexican chocolate', 'chocolate bar', 'chocolate candy',
      'chocolate cookie', 'chocolate cake', 'brownie', 'blondie', 'cookie',
      'chocolate chip cookie', 'sandwich cookie', 'oreo', 'ginger snap',
      'shortbread', 'butter cookie', 'sugar cookie', 'speculoos', 'biscotti',
      'waffle', 'pancake', 'crepe', 'donut', 'fritter', 'eclair', 'cream puff',
      'profiterole', 'macaron', 'macaroon', 'meringue', 'pavlova', 'baked alaska',
      'ice cream', 'gelato', 'sorbet', 'sherbet', 'frozen yogurt', 'popsicle',
      'ice pop', 'ice cream bar', 'ice cream sandwich', 'ice cream cone',
      'pudding', 'custard', 'flan', 'crème brûlée', 'panna cotta', 'rice pudding',
      'tapioca pudding', 'chocolate pudding', 'vanilla pudding', 'butterscotch pudding',
      'cheesecake', 'tiramisu', 'trifle', 'parfait', 'mousse', 'mousse cake',
      'chocolate mousse', 'fruit mousse', 'jello', 'gelatin dessert', 'gummy',
      'gummy bear', 'gummy worm', 'jelly bean', 'licorice', 'lollipop', 'hard candy',
      'caramel candy', 'toffee', 'fudge', 'truffle', 'chocolate truffle',
      'praline', 'nougat', 'halva', 'baklava', 'knafeh', 'kheer', 'halwa',
      'laddoo', 'burfi', 'ras malai', 'gulab jamun', 'jalebi', 'falooda'
    ])) {
      return Icons.cake_outlined;
    }
    
    // ============ FROZEN FOODS ============
    if (_containsAny(name, [
      'frozen', 'ice cream', 'sorbet', 'popsicle', 'ice pop', 'frozen dinner roll',
      'frozen dumpling', 'frozen meatball', 'frozen pizza roll', 'frozen yogurt',
      'french fry', 'french-fried onion', 'hash brown', 'waffle', 'pancake',
      'pierogi', 'potato dumpling', 'frozen berry', 'berry mix', 'frozen vegetable',
      'frozen fruit', 'frozen meal', 'tv dinner', 'frozen entree', 'frozen pizza',
      'frozen lasagna', 'frozen burrito', 'frozen taquito', 'frozen egg roll',
      'frozen spring roll', 'frozen chicken nugget', 'frozen chicken patty',
      'frozen fish stick', 'frozen shrimp', 'frozen crab cake', 'frozen burger patty'
    ])) {
      return Icons.ac_unit_outlined;
    }
    
    // ============ CANNED & PRESERVED ============
    if (_containsAny(name, [
      'canned', 'preserved', 'pickled', 'jar', 'fermented', 'pickle',
      'canned bean', 'canned corn', 'canned pea', 'canned tomato', 'canned fruit',
      'canned vegetable', 'canned soup', 'canned chili', 'canned stew',
      'canned tuna', 'canned salmon', 'canned sardine', 'canned crab', 'canned clam',
      'canned chicken', 'canned beef', 'canned ham', 'spam', 'canned chili',
      'canned baked bean', 'canned refried bean', 'canned bean soup',
      'canned minestrone', 'canned clam chowder', 'canned tomato soup',
      'canned mushroom soup', 'canned chicken soup', 'canned beef soup',
      'canned vegetable soup', 'canned potato', 'canned carrot', 'canned pea',
      'canned corn', 'canned green bean', 'canned mixed vegetable', 'canned fruit cocktail',
      'canned peach', 'canned pear', 'canned pineapple', 'canned cherry',
      'canned apple', 'canned apricot', 'canned mango', 'canned lychee',
      'canned mandarin', 'canned jackfruit', 'canned pie filling', 'canned pumpkin',
      'canned sweet potato', 'canned water chestnut', 'canned bamboo shoot',
      'canned artichoke', 'canned mushroom', 'canned olive', 'canned pepper',
      'canned jalapeno', 'canned green chile', 'canned tomato sauce', 'canned paste',
      'jarred sauce', 'jarred salsa', 'jarred pesto', 'jarred alfredo', 'jarred marinara',
      'pickle', 'dill pickle', 'bread and butter pickle', 'sweet pickle', 'sour pickle',
      'pickled onion', 'pickled pepper', 'pickled jalapeno', 'pickled beet',
      'pickled egg', 'pickled ginger', 'pickled garlic', 'pickled vegetable',
      'giardiniera', 'caper', 'olive', 'kalamata olive', 'green olive', 'black olive',
      'stuffed olive', 'roasted red pepper', 'sun-dried tomato', 'artichoke heart',
      'hearts of palm', 'palm heart', 'preserved lemon', 'chipotle in adobo',
      'adobo pepper', 'kimchi', 'sauerkraut', 'fermented vegetable', 'pickling liquid'
    ])) {
      return Icons.inventory_2_outlined;
    }
    
    // ============ DRIED FRUIT & PRESERVES ============
    if (_containsAny(name, [
      'dried fruit', 'raisin', 'prune', 'date', 'fig', 'apricot', 'cranberry',
      'blueberry', 'cherry', 'craisin', 'goji', 'sultana', 'currant', 'raisin',
      'dried apple', 'dried apricot', 'dried banana', 'dried berry', 'dried cherry',
      'dried cranberry', 'dried date', 'dried fig', 'dried mango', 'dried papaya',
      'dried peach', 'dried pear', 'dried pineapple', 'dried plum', 'dried tamarind',
      'dried persimmon', 'dried lime', 'dried lemon', 'dried orange', 'dried elderberry',
      'freeze-dried fruit', 'fruit leather', 'fruit roll-up', 'fruit snack',
      'jam', 'jelly', 'marmalade', 'preserve', 'conserve', 'fruit spread',
      'apple butter', 'apple jelly', 'apricot jam', 'blackberry jam', 'blueberry jam',
      'cherry jam', 'cranberry sauce', 'fig jam', 'grape jelly', 'hot pepper jelly',
      'mint jelly', 'orange marmalade', 'peach preserves', 'plum jam', 'raspberry jam',
      'red pepper jelly', 'strawberry jam', 'tomato jelly', 'currant jelly'
    ])) {
      return Icons.warehouse_outlined;
    }
    
    // ============ BABY FOOD ============
    if (_containsAny(name, [
      'baby', 'infant formula', 'toddler formula', 'teething biscuit',
      'baby puff', 'baby cereal', 'puree', 'baby food', 'baby yogurt melt',
      'rice rusk', 'baby snack', 'formula milk', 'infant formula powder',
      'follow-up formula', 'soy-based infant formula', 'hypoallergenic formula',
      'lactose-free baby formula', 'goat milk formula', 'ready-to-feed infant formula',
      'powdered baby milk', 'rice cereal baby', 'oat cereal baby', 'multigrain baby cereal',
      'wheat cereal baby', 'barley cereal baby', 'apple puree', 'banana puree',
      'pear puree', 'mango puree', 'carrot puree', 'pumpkin puree', 'sweet potato puree',
      'pea puree', 'spinach puree', 'avocado puree', 'chicken puree', 'beef puree',
      'lentil puree', 'fruit blend puree', 'vegetable blend puree',
      'chicken and rice puree', 'apple and banana puree', 'carrot and potato puree'
    ])) {
      return Icons.baby_changing_station_outlined;
    }
    
    // ============ SEAWEED ============
    if (_containsAny(name, [
      'seaweed', 'nori', 'kelp', 'wakame', 'dulse', 'hijiki', 'arame',
      'kombu', 'spirulina', 'chlorella', 'ogo seaweed', 'sea lettuce', 'sea moss',
      'korean seaweed', 'yaki-nori', 'kizami nori', 'aonori', 'gim', 'seaweed caviar',
      'seaweed salad', 'dried seaweed', 'roasted seaweed', 'seaweed snack'
    ])) {
      return Icons.waves_outlined;
    }
    
    // ============ HERBS & SUPPLEMENTS ============
    if (_containsAny(name, [
      'herb', 'supplement', 'vitamin', 'protein powder', 'collagen',
      'maca', 'ashwagandha', 'probiotic', 'psyllium', 'wheatgrass',
      'greens powder', 'cbd', 'thc', 'cannabis', 'herbal', 'adaptogen',
      'reishi', 'lion\'s mane', 'chaga', 'cordyceps', 'turkey tail',
      'moringa', 'spirulina', 'chlorella', 'blue spirulina', 'matcha',
      'morninga', 'baobab', 'camu camu', 'acai powder', 'wheatgrass powder',
      'barley grass', 'alfalfa powder', 'kelp powder', 'sea moss powder',
      'collagen peptide', 'collagen powder', 'whey protein', 'plant protein',
      'pea protein', 'rice protein', 'hemp protein', 'soy protein', 'casein',
      'creatine', 'bcaa', 'glutamine', 'beta-alanine', 'carnitine', 'CLA',
      'l-carnitine', 'magnesium', 'calcium', 'zinc', 'iron', 'vitamin c',
      'vitamin d', 'vitamin e', 'vitamin b', 'multivitamin', 'probiotic',
      'prebiotic', 'digestive enzyme', 'fiber supplement', 'psyllium husk',
      'inulin', 'milk thistle', 'echinacea', 'elderberry syrup', 'ginger supplement',
      'turmeric supplement', 'ashwagandha powder', 'reishi mushroom', 'chaga mushroom',
      'lion\'s mane mushroom', 'cordyceps mushroom', 'mushroom powder',
      'functional mushroom', 'medicinal mushroom', 'herbal tincture', 'herbal extract'
    ])) {
      return Icons.healing_outlined;
    }
    
    // ============ MUSHROOMS & FUNGI ============
    if (_containsAny(name, [
      'mushroom', 'fungus', 'shiitake', 'maitake', 'enoki', 'oyster mushroom',
      'portobello', 'cremini', 'button mushroom', 'porcini', 'morel', 'chanterelle',
      'truffle', 'nameko', 'shimeji', 'lion\'s mane', 'reishi', 'chaga',
      'white beech mushroom', 'brown cap mushroom', 'chestnut mushroom',
      'king oyster mushroom', 'pioppini', 'straw mushroom', 'black fungus',
      'white fungus', 'snow fungus', 'wood ear', 'jelly ear', 'caesar\'s mushroom',
      'candy cap mushroom', 'field mushroom', 'huitlacoche', 'corn smut',
      'puffball', 'trumpet mushroom', 'wild mushroom', 'mixed mushroom',
      'dried mushroom', 'mushroom powder', 'mushroom broth', 'mushroom stock'
    ])) {
      return Icons.grass_outlined;
    }
    
    // ============ TOFU & MEAT ALTERNATIVES ============
    if (_containsAny(name, [
      'tofu', 'tempeh', 'seitan', 'textured vegetable protein', 'tvp',
      'soy curls', 'quorn', 'vegan chicken', 'vegan beef', 'vegan sausage',
      'vegan bacon', 'vegan pepperoni', 'vegan meatball', 'vegetarian hot dog',
      'vegan burger', 'plant-based meat', 'meat alternative', 'meat substitute',
      'plant protein', 'tofu skin', 'tofu puffs', 'fried tofu', 'silken tofu',
      'firm tofu', 'extra firm tofu', 'smoked tofu', 'marinated tofu', 'tofu scramble',
      'tofurky', 'seitan', 'wheat meat', 'mock duck', 'mock chicken', 'mock pork'
    ])) {
      return Icons.forest_outlined;
    }
    
    // ============ SNACKS & OTHER ============
    if (_containsAny(name, [
      'snack', 'chip', 'cracker', 'pretzel', 'popcorn', 'trail mix', 'granola bar',
      'protein bar', 'energy bar', 'nut bar', 'rice cake', 'popcake', 'puffed snack',
      'vegan snack', 'gluten-free snack', 'keto snack', 'paleo snack', 'almond pulp',
      'bee pollen', 'blue spirulina', 'citric acid', 'mastic gum', 'smoking wood',
      'wonton strips', 'crispy onion', 'bacon bits', 'coconut chip', 'plantain chip',
      'vegetable chip', 'kale chip', 'seaweed snack', 'roasted chickpea', 'roasted nut',
      'spiced nut', 'candied nut', 'chocolate-covered nut', 'chocolate-covered fruit'
    ])) {
      return Icons.fastfood_outlined;
    }
    
    // ============ DEFAULT - PANTRY ============
    return Icons.kitchen_outlined;
  }
  
  static bool _containsAny(String text, List<String> keywords) {
    for (final word in keywords) {
      if (text.contains(word)) return true;
    }
    return false;
  }
}