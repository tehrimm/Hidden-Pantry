import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/models/review.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('Review Model Tests', () {
    test('Review model correctly parses DateTime from a timestamp', () {
      final now = DateTime.now();
      final json = {
        'id': 'rev1',
        'comment': 'Good',
        'rating': 5.0,
        'createdAt': Timestamp.fromDate(now),
      };
      
      final review = Review.fromJson(json);
      // Compare to nearest second as millisecond precision might be lost in some conversions
      expect(review.createdAt.difference(now).inSeconds.abs() < 1, isTrue);
    });

    test('Review model correctly parses DateTime from a string', () {
      final dateStr = '2023-10-27T10:00:00Z';
      final json = {
        'id': 'rev2',
        'comment': 'Nice',
        'rating': 4.0,
        'createdAt': dateStr,
      };
      
      final review = Review.fromJson(json);
      expect(review.createdAt.isAtSameMomentAs(DateTime.parse(dateStr)), isTrue);
    });

    test('Review rating is parsed correctly', () {
      final json = {
        'id': 'rev3',
        'comment': 'Excellent dish!',
        'rating': 4.5,
        'createdAt': '2024-06-01T00:00:00Z',
      };
      final review = Review.fromJson(json);
      expect(review.rating, 4.5);
    });

    test('Review id and comment are stored correctly', () {
      final json = {
        'id': 'rev4',
        'comment': 'Would make again',
        'rating': 5.0,
        'createdAt': '2024-07-15T00:00:00Z',
      };
      final review = Review.fromJson(json);
      expect(review.id, 'rev4');
      expect(review.comment, 'Would make again');
    });
  });
}
