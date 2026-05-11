import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

void main() {
  var ing = Recipe.parseIngredient('4 large potatoes');
  print('Result: name=${ing?.name}, qty=${ing?.quantity}, unit=${ing?.unit}');
}
