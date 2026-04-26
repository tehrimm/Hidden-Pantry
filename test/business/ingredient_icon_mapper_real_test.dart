import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/utils/ingredient_icon_mapper.dart';

void main() {
  group('Real Business Tests: IngredientIconMapper', () {
    test('Maps beverages correctly', () {
      expect(IngredientIconMapper.getIcon('Water'), Icons.local_cafe_outlined);
      expect(IngredientIconMapper.getIcon('apple juice'), Icons.local_cafe_outlined);
      expect(IngredientIconMapper.getIcon('coca cola soda'), Icons.local_cafe_outlined);
    });

    test('Maps alcoholic beverages correctly', () {
      expect(IngredientIconMapper.getIcon('Red Wine'), Icons.local_bar_outlined);
      expect(IngredientIconMapper.getIcon('Vodka'), Icons.local_bar_outlined);
      expect(IngredientIconMapper.getIcon('craft beer'), Icons.local_bar_outlined);
    });

    test('Maps meat and poultry correctly', () {
      expect(IngredientIconMapper.getIcon('chicken breast'), Icons.food_bank_outlined);
      expect(IngredientIconMapper.getIcon('Ground Beef'), Icons.food_bank_outlined);
      expect(IngredientIconMapper.getIcon('smoked bacon'), Icons.food_bank_outlined);
    });

    test('Maps seafood correctly', () {
      expect(IngredientIconMapper.getIcon('salmon fillet'), Icons.emoji_food_beverage_outlined);
      expect(IngredientIconMapper.getIcon('shrimp'), Icons.emoji_food_beverage_outlined);
      expect(IngredientIconMapper.getIcon('canned tuna'), Icons.emoji_food_beverage_outlined);
    });

    test('Maps vegetables correctly', () {
      expect(IngredientIconMapper.getIcon('red onion'), Icons.eco_outlined);
      expect(IngredientIconMapper.getIcon('garlic cloves'), Icons.eco_outlined);
      expect(IngredientIconMapper.getIcon('baby spinach'), Icons.eco_outlined);
    });

    test('Maps fruits correctly', () {
      expect(IngredientIconMapper.getIcon('granny smith apple'), Icons.forest_outlined);
      expect(IngredientIconMapper.getIcon('ripe banana'), Icons.forest_outlined);
      expect(IngredientIconMapper.getIcon('strawberries'), Icons.forest_outlined);
    });

    test('Maps dairy and eggs correctly', () {
      expect(IngredientIconMapper.getIcon('large egg'), Icons.egg_outlined);
      expect(IngredientIconMapper.getIcon('whole milk'), Icons.egg_alt_outlined);
      expect(IngredientIconMapper.getIcon('cheddar cheese'), Icons.egg_alt_outlined);
    });

    test('Maps grains, bread and pasta correctly', () {
      expect(IngredientIconMapper.getIcon('white rice'), Icons.bakery_dining_outlined);
      expect(IngredientIconMapper.getIcon('spaghetti pasta'), Icons.bakery_dining_outlined);
      expect(IngredientIconMapper.getIcon('sourdough bread'), Icons.bakery_dining_outlined);
    });

    test('Maps spices and seasonings correctly', () {
      expect(IngredientIconMapper.getIcon('sea salt'), Icons.restaurant_menu_outlined);
      expect(IngredientIconMapper.getIcon('black pepper'), Icons.restaurant_menu_outlined);
      expect(IngredientIconMapper.getIcon('fresh basil'), Icons.restaurant_menu_outlined);
    });

    test('Maps sauces and oils correctly', () {
      expect(IngredientIconMapper.getIcon('soy sauce'), Icons.science_outlined);
      expect(IngredientIconMapper.getIcon('ketchup'), Icons.science_outlined);
      expect(IngredientIconMapper.getIcon('olive oil'), Icons.opacity_outlined);
    });

    test('Maps sweeteners and baking ingredients correctly', () {
      expect(IngredientIconMapper.getIcon('brown sugar'), Icons.cookie_outlined);
      expect(IngredientIconMapper.getIcon('honey'), Icons.cookie_outlined);
      expect(IngredientIconMapper.getIcon('baking powder'), Icons.kitchen_outlined);
    });

    test('Falls back to default kitchen icon for unknown ingredients', () {
      expect(IngredientIconMapper.getIcon('unidentifiable space food'), Icons.kitchen_outlined);
      expect(IngredientIconMapper.getIcon('random 12345'), Icons.kitchen_outlined);
    });
  });
}
