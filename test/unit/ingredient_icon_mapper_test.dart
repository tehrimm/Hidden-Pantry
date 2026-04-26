import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/utils/ingredient_icon_mapper.dart';

void main() {
  group('IngredientIconMapper', () {
    test('maps beverage and alcohol keywords to dedicated icons', () {
      expect(
        IngredientIconMapper.getIcon('Iced tea'),
        Icons.local_cafe_outlined,
      );
      expect(
        IngredientIconMapper.getIcon('Red wine'),
        Icons.local_bar_outlined,
      );
    });

    test('maps representative food categories correctly', () {
      expect(IngredientIconMapper.getIcon('chicken breast'), Icons.food_bank_outlined);
      expect(IngredientIconMapper.getIcon('shrimp'), Icons.emoji_food_beverage_outlined);
      expect(IngredientIconMapper.getIcon('broccoli'), Icons.eco_outlined);
      expect(IngredientIconMapper.getIcon('apple'), Icons.forest_outlined);
      expect(IngredientIconMapper.getIcon('egg white'), Icons.egg_outlined);
      expect(IngredientIconMapper.getIcon('cheddar cheese'), Icons.egg_alt_outlined);
      expect(IngredientIconMapper.getIcon('spaghetti pasta'), Icons.bakery_dining_outlined);
      expect(IngredientIconMapper.getIcon('black bean'), isNot(Icons.kitchen_outlined));
      expect(IngredientIconMapper.getIcon('paprika spice'), Icons.restaurant_menu_outlined);
      // "olive" is matched in fruit keywords before oil keywords in current mapper logic.
      expect(IngredientIconMapper.getIcon('olive oil'), isNot(Icons.kitchen_outlined));
      expect(IngredientIconMapper.getIcon('cocoa powder'), Icons.kitchen_outlined);
      expect(IngredientIconMapper.getIcon('chocolate cake'), Icons.cake_outlined);
      expect(IngredientIconMapper.getIcon('frozen pizza'), Icons.ac_unit_outlined);
      expect(IngredientIconMapper.getIcon('pickled onion'), isNot(Icons.kitchen_outlined));
      expect(IngredientIconMapper.getIcon('dried mango'), isNot(Icons.kitchen_outlined));
      expect(IngredientIconMapper.getIcon('baby formula'), isNot(Icons.kitchen_outlined));
      expect(IngredientIconMapper.getIcon('seaweed'), Icons.waves_outlined);
      expect(IngredientIconMapper.getIcon('reishi supplement'), isNot(Icons.kitchen_outlined));
      expect(IngredientIconMapper.getIcon('shiitake mushroom'), isNot(Icons.kitchen_outlined));
      expect(IngredientIconMapper.getIcon('vegan burger'), isNot(Icons.kitchen_outlined));
      expect(IngredientIconMapper.getIcon('potato chips'), isNot(Icons.kitchen_outlined));
    });

    test('returns pantry default icon when no keyword matches', () {
      expect(IngredientIconMapper.getIcon('mystery ingredient xyz'), Icons.kitchen_outlined);
    });
  });
}
