import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hidden_pantry_app/features/user/models/user_model.dart';

void main() {
  test('UserModel toMap contains expected fields', () {
    final u = UserModel(
      uid: 'u1',
      email: 'user@example.com',
      fullName: 'Test User',
      role: 'homecook',
      allergies: const ['milk', 'peanuts'],
      createdAt: DateTime.parse('2025-01-01T12:00:00Z'),
    );
    final m = u.toMap();

    expect(m['email'], equals('user@example.com'));
    expect(m['fullName'], equals('Test User'));
    expect(m['role'], equals('homecook'));
    expect(m['allergies'], equals(['milk', 'peanuts']));
    expect(m['createdAt'], isA<Timestamp>());
  });
}

