import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/models/cookbook.dart';

void main() {
  group('Cookbook Model Tests', () {
    test('Cookbook constructor should initialize correctly', () {
      final now = DateTime.now();
      final cookbook = Cookbook(
        id: 'cb1',
        title: 'Healthy Eats',
        description: 'My favorite healthy recipes',
        recipeIds: ['r1', 'r2'],
        createdAt: now,
      );

      expect(cookbook.id, 'cb1');
      expect(cookbook.title, 'Healthy Eats');
      expect(cookbook.description, 'My favorite healthy recipes');
      expect(cookbook.recipeIds, ['r1', 'r2']);
      expect(cookbook.createdAt, now);
    });

    test('toJson should return correct map', () {
      final now = DateTime.now();
      final cookbook = Cookbook(
        id: 'cb1',
        title: 'Healthy Eats',
        recipeIds: ['r1'],
        createdAt: now,
      );

      final json = cookbook.toJson();

      expect(json['title'], 'Healthy Eats');
      expect(json['recipeIds'], ['r1']);
      expect(json['createdAt'], now);
    });

    test('copyWith should update fields correctly', () {
      final cookbook = Cookbook(
        id: 'cb1',
        title: 'Old Title',
      );

      final updated = cookbook.copyWith(title: 'New Title', description: 'New Desc');

      expect(updated.id, 'cb1'); // ID should remain same
      expect(updated.title, 'New Title');
      expect(updated.description, 'New Desc');
    });

    test('recipeIds defaults to empty list when not provided', () {
      final cookbook = Cookbook(id: 'cb2', title: 'Empty Book');
      expect(cookbook.recipeIds, isEmpty);
    });

    test('Cookbook title cannot be overwritten incorrectly via copyWith', () {
      final cookbook = Cookbook(id: 'cb3', title: 'Original');
      final copy = cookbook.copyWith();
      expect(copy.title, 'Original');
    });
  });
}
