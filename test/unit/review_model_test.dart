import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/models/review.dart';

void main() {
  test('Review toFirestore includes server timestamp keys', () {
    final r = Review(
      id: 'rev1',
      recipeId: 'r1',
      userId: 'u1',
      userName: 'Alice',
      userImageUrl: 'http://img',
      comment: 'Nice!',
      rating: 5,
      createdAt: DateTime.now(),
    );
    final map = r.toFirestore();
    expect(map['recipeId'], 'r1');
    expect(map['userId'], 'u1');
    expect(map['comment'], 'Nice!');
    // createdAt is server timestamp; we just assert key exists
    expect(map.containsKey('createdAt'), true);
  });
}

