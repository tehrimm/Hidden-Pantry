import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/nutritionist/models/nutritionist_model.dart';

void main() {
  group('Nutritionist Model Tests', () {
    test('Nutritionist model parses Stripe connected account ID correctly', () {
      final now = DateTime.now();
      final nutritionist = Nutritionist(
        uid: 'nut_1',
        fullName: 'Jane Smith',
        email: 'jane@example.com',
        phoneNumber: '0987654321',
        licenseNumber: 'L67890',
        certificateUrl: 'https://example.com/cert.pdf',
        verificationStatus: 'approved',
        hasLoggedInAfterRejection: false,
        createdAt: now,
        updatedAt: now,
        stripeConnectedAccountId: 'acct_123456789',
      );

      expect(nutritionist.stripeConnectedAccountId, 'acct_123456789');
    });

    test('Nutritionist constructor and status getters', () {
      final now = DateTime.now();
      final nutritionist = Nutritionist(
        uid: 'nut1',
        fullName: 'Jane Smith',
        email: 'jane@example.com',
        phoneNumber: '1234567890',
        licenseNumber: 'LIC123',
        certificateUrl: 'http://cert.com',
        verificationStatus: 'pending',
        hasLoggedInAfterRejection: false,
        createdAt: now,
        updatedAt: now,
      );

      expect(nutritionist.uid, 'nut1');
      expect(nutritionist.isPending, isTrue);
      expect(nutritionist.isApproved, isFalse);
      expect(nutritionist.isRejected, isFalse);
    });

    test('copyWith should work correctly', () {
      final now = DateTime.now();
      final nutritionist = Nutritionist(
        uid: 'nut1',
        fullName: 'Jane Smith',
        email: 'jane@example.com',
        phoneNumber: '1234567890',
        licenseNumber: 'LIC123',
        certificateUrl: 'http://cert.com',
        verificationStatus: 'pending',
        hasLoggedInAfterRejection: false,
        createdAt: now,
        updatedAt: now,
      );

      final approved = nutritionist.copyWith(verificationStatus: 'approved');
      expect(approved.verificationStatus, 'approved');
      expect(approved.isApproved, isTrue);
      expect(approved.uid, 'nut1');
    });
  });
}
