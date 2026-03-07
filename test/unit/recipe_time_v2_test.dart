import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

Recipe mk(int minutes) => Recipe(
      id: 'r$minutes',
      name: 'R$minutes',
      minutes: minutes,
      avgRating: 4.0,
      directions: const [],
    );

void main() {
  group('[Unit][Recipe][Time]', () {
    test('[Unit][Recipe][Time] short recipe under 20', () {
      final r = mk(10);
      expect(r.prepMinutes, 10);
      expect(r.cookMinutes, 0);
    });
    test('[Unit][Recipe][Time] exactly 20', () {
      final r = mk(20);
      expect(r.prepMinutes, 15);
      expect(r.cookMinutes, 5);
    });
    test('[Unit][Recipe][Time] longer recipe 45', () {
      final r = mk(45);
      expect(r.prepMinutes, 15);
      expect(r.cookMinutes, 30);
    });
  });
}

