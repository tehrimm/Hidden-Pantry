import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hidden_pantry_app/features/nutritionist/models/nutritionist_model.dart';

void main() {
  group('Integration: RBAC nutritionist actions', () {
    test('isApproved/isPending/isRejected reflect verificationStatus', () {
      final now = DateTime.now();
      Nutritionist approved = Nutritionist.fromJson({
        'uid': 'u1',
        'fullName': 'A',
        'email': 'a@x.com',
        'phoneNumber': '1',
        'licenseNumber': 'L',
        'certificateUrl': 'url',
        'verificationStatus': 'approved',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });
      Nutritionist pending = approved.copyWith(verificationStatus: 'pending');
      Nutritionist rejected = approved.copyWith(verificationStatus: 'rejected');
      expect(approved.isApproved, true);
      expect(pending.isPending, true);
      expect(rejected.isRejected, true);
    });
  });
}

