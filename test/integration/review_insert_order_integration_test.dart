import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/state/state_management.dart';

void main() {
  group('Integration: Review insert order', () {
    test('Newest first', () {
      final r = ReviewController();
      r.pushReview('first');
      r.pushReview('second');
      expect(r.reviews.first, 'second');
      expect(r.reviews.length, 2);
    });
  });
}

