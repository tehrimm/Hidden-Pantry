import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/utils/ingredient_icon_mapper.dart';

void main() {
  group('Real Business Tests: IngredientIconMapper', () {
    test('Maps beverages correctly', () {
      expect(IngredientIconMapper.getIcon('Water'), material.Icons.local_cafe_outlined);
      expect(IngredientIconMapper.getIcon('apple juice'), material.Icons.local_cafe_outlined);
      expect(IngredientIconMapper.getIcon('coca cola soda'), material.Icons.local_cafe_outlined);
    });

    test('Maps alcoholic beverages correctly', () {
      expect(IngredientIconMapper.getIcon('Red Wine'), material.Icons.local_bar_outlined);
      expect(IngredientIconMapper.getIcon('Vodka'), material.Icons.local_bar_outlined);
      expect(IngredientIconMapper.getIcon('craft beer'), material.Icons.local_bar_outlined);
    });

    test('Maps meat and poultry correctly', () {
      expect(IngredientIconMapper.getIcon('chicken breast'), material.Icons.food_bank_outlined);
      expect(IngredientIconMapper.getIcon('Ground Beef'), material.Icons.food_bank_outlined);
      expect(IngredientIconMapper.getIcon('smoked bacon'), material.Icons.food_bank_outlined);
    });

    test('Maps seafood correctly', () {
      expect(IngredientIconMapper.getIcon('salmon fillet'), material.Icons.emoji_food_beverage_outlined);
      expect(IngredientIconMapper.getIcon('shrimp'), material.Icons.emoji_food_beverage_outlined);
      expect(IngredientIconMapper.getIcon('canned tuna'), material.Icons.emoji_food_beverage_outlined);
    });

    test('Maps vegetables correctly', () {
      expect(IngredientIconMapper.getIcon('red onion'), material.Icons.eco_outlined);
      expect(IngredientIconMapper.getIcon('garlic cloves'), material.Icons.eco_outlined); // Now matches 'garlic' in VEGETABLES
      expect(IngredientIconMapper.getIcon('baby spinach'), material.Icons.eco_outlined);
    });

    test('Maps fruits correctly', () {
      expect(IngredientIconMapper.getIcon('granny smith apple'), material.Icons.forest_outlined);
      expect(IngredientIconMapper.getIcon('ripe banana'), material.Icons.forest_outlined);
      expect(IngredientIconMapper.getIcon('strawberries'), material.Icons.forest_outlined);
    });

    test('Maps dairy and eggs correctly', () {
      expect(IngredientIconMapper.getIcon('large egg'), material.Icons.egg_outlined);
      expect(IngredientIconMapper.getIcon('whole milk'), material.Icons.egg_alt_outlined);
      expect(IngredientIconMapper.getIcon('cheddar cheese'), material.Icons.egg_alt_outlined);
    });

    test('Maps grains, bread and pasta correctly', () {
      expect(IngredientIconMapper.getIcon('white rice'), material.Icons.bakery_dining_outlined);
      expect(IngredientIconMapper.getIcon('spaghetti pasta'), material.Icons.bakery_dining_outlined);
      expect(IngredientIconMapper.getIcon('sourdough bread'), material.Icons.bakery_dining_outlined);
    });

    test('Maps spices and seasonings correctly', () {
      expect(IngredientIconMapper.getIcon('sea salt'), material.Icons.restaurant_menu_outlined);
      expect(IngredientIconMapper.getIcon('black pepper'), material.Icons.restaurant_menu_outlined);
      expect(IngredientIconMapper.getIcon('fresh basil'), material.Icons.restaurant_menu_outlined);
    });

    test('Maps sauces and oils correctly', () {
      expect(IngredientIconMapper.getIcon('soy sauce'), material.Icons.science_outlined); // Now matches 'soy sauce' in SAUCES first
      expect(IngredientIconMapper.getIcon('ketchup'), material.Icons.science_outlined);
      expect(IngredientIconMapper.getIcon('olive oil'), material.Icons.opacity_outlined);
    });

    test('Maps sweeteners and baking ingredients correctly', () {
      expect(IngredientIconMapper.getIcon('brown sugar'), material.Icons.cookie_outlined);
      expect(IngredientIconMapper.getIcon('honey'), material.Icons.cookie_outlined);
      expect(IngredientIconMapper.getIcon('baking powder'), material.Icons.kitchen_outlined);
    });

    test('Falls back to default kitchen icon for unknown ingredients', () {
      expect(IngredientIconMapper.getIcon('unidentifiable space food'), material.Icons.kitchen_outlined);
      expect(IngredientIconMapper.getIcon('random 12345'), material.Icons.kitchen_outlined);
    });
  });
}
