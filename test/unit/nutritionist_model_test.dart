import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hidden_pantry_app/features/nutritionist/models/nutritionist_model.dart';

void main() {
  group('Nutritionist Model Coverage', () {
    final now = DateTime.now();

    test('isApproved, isPending, isRejected getters', () {
      final pending = Nutritionist(
        uid: '1',
        fullName: 'Pending',
        email: 'p@ex.com',
        createdAt: now,
        updatedAt: now,
      );
      expect(pending.isPending, isTrue);
      expect(pending.isApproved, isFalse);
      expect(pending.isRejected, isFalse);

      final approved = pending.copyWith(verificationStatus: 'approved');
      expect(approved.isApproved, isTrue);

      final rejected = pending.copyWith(verificationStatus: 'rejected');
      expect(rejected.isRejected, isTrue);
    });

    test('copyWith updates fields correctly', () {
      final orig = Nutritionist(
        uid: '1',
        fullName: 'Orig',
        email: 'o@ex.com',
        createdAt: now,
        updatedAt: now,
      );

      final updated = orig.copyWith(
        fullName: 'New',
        stripeConnectedAccountId: 'acct_123',
      );

      expect(updated.fullName, 'New');
      expect(updated.stripeConnectedAccountId, 'acct_123');
      expect(updated.uid, '1'); // Unchanged
    });

    test('fromJson and toJson covers all property parsing', () {
      final jsonMap = {
        'uid': 'n1',
        'fullName': 'Dr. Nutri',
        'email': 'n@ex.com',
        'phoneNumber': '123',
        'licenseNumber': 'L123',
        'certificateUrl': 'http',
        'organizationName': 'Org',
        'expiryDate': '2030-01-01',
        'verificationStatus': 'approved',
        'rejectionReason': 'none',
        'hasLoggedInAfterRejection': true,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': now.millisecondsSinceEpoch,
        'stripeConnectedAccountId': 'stripe_1',
      };

      final nutritionist = Nutritionist.fromJson(jsonMap);

      expect(nutritionist.uid, 'n1');
      expect(nutritionist.isApproved, isTrue);
      expect(nutritionist.hasLoggedInAfterRejection, isTrue);
      expect(nutritionist.stripeConnectedAccountId, 'stripe_1');

      final exported = nutritionist.toJson();

      expect(exported['uid'], 'n1');
      expect(exported['stripeConnectedAccountId'], 'stripe_1');
      expect(exported['rejectionDate'], isNull);
    });

    test('fromJson handles nulls and fallbacks', () {
      final jsonMap = {
        'uid': 'n1',
      };

      final nutritionist = Nutritionist.fromJson(jsonMap);
      expect(nutritionist.email, '');
      expect(nutritionist.isPending, isTrue);
      expect(nutritionist.hasLoggedInAfterRejection, isFalse);
      expect(nutritionist.createdAt.year, DateTime.now().year);
    });
  });
}
