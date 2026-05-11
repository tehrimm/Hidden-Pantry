import '../lib/features/recipes/models/recipe.dart';

void main() {
  List<String> samples = [
    '1 large potato',
    '2 onions',
    '3 garlic',
    '1 large potato 1 L',
    '2 nion 2',
    '1 l',
    '4 large potatoes',
  ];
  for (var s in samples) {
    var item = Recipe.parseIngredient(s);
    print('Input: "$s" -> name: "${item?.name}", qty: ${item?.quantity}, unit: "${item?.unit}"');
  }
}
