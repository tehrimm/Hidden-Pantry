import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hidden_pantry_app/features/nutritionist/models/nutritionist_model.dart';

void main() {
  group('Nutritionist model', () {
    test('fromJson and toJson round-trip basics', () {
      final now = DateTime.now();
      final json = {
        'uid': 'n1',
        'fullName': 'Nutri One',
        'email': 'n1@example.com',
        'phoneNumber': '123456789',
        'licenseNumber': 'LIC-001',
        'certificateUrl': 'https://example.com/cert.png',
        'organizationName': 'Org',
        'expiryDate': '2028-12-31',
        'verificationStatus': 'pending',
        'rejectionReason': null,
        'rejectionDate': null,
        'hasLoggedInAfterRejection': false,
        'lastLoginAt': null,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'stripeConnectedAccountId': null,
      };

      final n = Nutritionist.fromJson(json);
      final out = n.toJson();

      expect(out['uid'], equals('n1'));
      expect(out['fullName'], equals('Nutri One'));
      expect(out['email'], equals('n1@example.com'));
      expect(out['verificationStatus'], equals('pending'));
      expect(out['createdAt'], isA<Timestamp>());
      expect(out['updatedAt'], isA<Timestamp>());
    });

    test('copyWith updates selected fields', () {
      final n = Nutritionist(
        uid: 'n1',
        fullName: 'Nutri One',
        email: 'n1@example.com',
        phoneNumber: '123456789',
        licenseNumber: 'LIC-001',
        certificateUrl: 'cert',
        verificationStatus: 'pending',
        hasLoggedInAfterRejection: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final n2 = n.copyWith(fullName: 'Nutri Two', verificationStatus: 'approved');
      expect(n2.fullName, equals('Nutri Two'));
      expect(n2.isApproved, isTrue);
      expect(n2.isPending, isFalse);
    });
  });
}

