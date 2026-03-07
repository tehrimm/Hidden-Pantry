import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/models/cookbook.dart';

void main() {
  test('Cookbook fromJson/toJson roundtrip basics', () {
    final cb = Cookbook(
      id: 'cb1',
      title: 'My Book',
      description: 'desc',
      recipeIds: const ['r1', 'r2'],
      imageUrl: 'http://img',
    );
    final json = cb.toJson();
    expect(json['title'], 'My Book');
    expect(json['recipeIds'], contains('r1'));

    final from = Cookbook.fromJson({
      'title': 'Imported',
      'description': 'd',
      'recipeIds': ['a', 'b'],
      'imageUrl': 'x',
    }, 'doc123');
    expect(from.id, 'doc123');
    expect(from.title, 'Imported');
    expect(from.recipeIds.length, 2);
  });
}
