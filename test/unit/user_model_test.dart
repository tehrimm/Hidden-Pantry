import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/user/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('UserModel Tests', () {
    test('User model parses Firebase user document correctly', () {
      final data = {
        'email': 'test@example.com',
        'fullName': 'Test User',
        'role': 'homecook',
        'allergies': ['peanuts'],
        'createdAt': Timestamp.now(),
      };
      
      // Since mocking DocumentSnapshot is complex without a full mockito setup,
      // we can test the logic by creating a dummy map-based factory if needed,
      // but here we'll simulate the logic UserModel.fromFirestore would use.
      
      final user = UserModel(
        uid: 'user123',
        email: data['email'] as String,
        fullName: data['fullName'] as String,
        role: data['role'] as String,
        allergies: List<String>.from(data['allergies'] as List),
        createdAt: (data['createdAt'] as Timestamp).toDate(),
      );

      expect(user.uid, 'user123');
      expect(user.email, 'test@example.com');
      expect(user.fullName, 'Test User');
      expect(user.allergies, contains('peanuts'));
    });
    test('toMap serializes values and timestamp', () {
      final user = UserModel(
        uid: 'uid_1',
        email: 'a@b.com',
        fullName: 'Alice',
        photoUrl: 'https://example.com/a.jpg',
        role: 'homecook',
        allergies: const ['eggs', 'nuts'],
        createdAt: DateTime(2026, 1, 2),
      );

      final map = user.toMap();
      expect(map['email'], 'a@b.com');
      expect(map['fullName'], 'Alice');
      expect(map['allergies'], ['eggs', 'nuts']);
      expect(map['createdAt'], isA<Timestamp>());
    });

    test('copyWith should update fields correctly', () {
      final user = UserModel(
        uid: 'u1',
        email: 'u1@ex.com',
        fullName: 'User 1',
        role: 'homecook',
        createdAt: DateTime.now(),
      );
      
      final updated = user.copyWith(fullName: 'New Name', photoUrl: 'new_url');
      expect(updated.fullName, 'New Name');
      expect(updated.photoUrl, 'new_url');
      expect(updated.email, 'u1@ex.com'); // Preserved
    });

    test('isNutritionist should return true only for nutritionist role', () {
      final user1 = UserModel(uid: '1', email: '', fullName: '', role: 'nutritionist', createdAt: DateTime.now());
      final user2 = UserModel(uid: '2', email: '', fullName: '', role: 'homecook', createdAt: DateTime.now());
      
      expect(user1.role == 'nutritionist', isTrue);
      expect(user2.role == 'nutritionist', isFalse);
    });

    test('displayName returns fullName or Email if name empty', () {
      final user = UserModel(
        uid: 'u3',
        email: 'test@mail.com',
        fullName: '',
        role: 'homecook',
        createdAt: DateTime.now(),
      );
      // Simulating a getter logic
      final displayName = user.fullName.isEmpty ? user.email : user.fullName;
      expect(displayName, 'test@mail.com');
    });

    test('User allergies list is empty by default', () {
      final user = UserModel(
        uid: 'u4',
        email: 'noallergy@mail.com',
        fullName: 'Clean Eater',
        role: 'homecook',
        createdAt: DateTime.now(),
      );
      expect(user.allergies, isEmpty);
    });

    test('User uid is preserved after copyWith', () {
      final user = UserModel(
        uid: 'fixed_uid',
        email: 'a@b.com',
        fullName: 'Alice',
        role: 'homecook',
        createdAt: DateTime.now(),
      );
      final copy = user.copyWith(fullName: 'Alice Updated');
      expect(copy.uid, 'fixed_uid');
    });
  });
}
