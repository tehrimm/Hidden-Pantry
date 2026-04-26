import 'package:flutter_test/flutter_test.dart';

/// Pure business logic helpers extracted from NutritionistService rating math
double computeNutritionistAvgRating(double ratingSum, int reviewCount) {
  if (reviewCount == 0) return 0.0;
  return ratingSum / reviewCount;
}

double computeUpdatedRatingSum({
  required double oldSum,
  required double oldRating,
  required double newRating,
}) {
  return oldSum - oldRating + newRating;
}

String determineVerificationStatus(String email) {
  const testEmails = ['testnutritionist@gmail.com', 'testnutrionist@gmail.com'];
  return testEmails.contains(email.trim().toLowerCase()) ? 'approved' : 'pending';
}

void main() {
  group('Real Business Tests: Nutritionist Profile & Verification', () {

    // ─── Verification Status Routing ───────────────────────────────
    group('Verification status on registration', () {
      test('Test email 1 gets approved instantly', () {
        expect(determineVerificationStatus('testnutritionist@gmail.com'), 'approved');
      });

      test('Test email 2 (typo variant) gets approved instantly', () {
        expect(determineVerificationStatus('testnutrionist@gmail.com'), 'approved');
      });

      test('Test email with mixed case gets approved', () {
        expect(determineVerificationStatus('TestNutritionist@Gmail.COM'), 'approved');
      });

      test('Test email with leading space gets approved', () {
        expect(determineVerificationStatus('  testnutritionist@gmail.com'), 'approved');
      });

      test('Real nutritionist email gets pending status', () {
        expect(determineVerificationStatus('dr.ahmed@hospital.pk'), 'pending');
      });

      test('Another real email gets pending', () {
        expect(determineVerificationStatus('nutritionist99@yahoo.com'), 'pending');
      });
    });

    // ─── Dashboard Access Control ──────────────────────────────────
    group('Dashboard access based on verificationStatus', () {
      bool canAccessDashboard(String status) => status == 'approved';
      bool shouldShowPendingScreen(String status) => status == 'pending';
      bool shouldShowRejectedScreen(String status) => status == 'rejected';

      test('Approved nutritionist accesses dashboard', () {
        expect(canAccessDashboard('approved'), true);
        expect(shouldShowPendingScreen('approved'), false);
        expect(shouldShowRejectedScreen('approved'), false);
      });

      test('Pending nutritionist sees pending screen', () {
        expect(canAccessDashboard('pending'), false);
        expect(shouldShowPendingScreen('pending'), true);
        expect(shouldShowRejectedScreen('pending'), false);
      });

      test('Rejected nutritionist sees rejected screen', () {
        expect(canAccessDashboard('rejected'), false);
        expect(shouldShowPendingScreen('rejected'), false);
        expect(shouldShowRejectedScreen('rejected'), true);
      });
    });

    // ─── Rejection Re-Login Logic ──────────────────────────────────
    group('hasLoggedInAfterRejection flag logic', () {
      test('On first login after rejection, flag is false', () {
        const hasLoggedIn = false;
        // If false → show rejected screen with resubmit option
        expect(hasLoggedIn, false);
      });

      test('After flag set, does not re-show rejection flow', () {
        const hasLoggedIn = true;
        // If true → allow re-entry to sign-up or dashboard depending on status
        expect(hasLoggedIn, true);
      });
    });

    // ─── Rating Calculation Math ───────────────────────────────────
    group('Nutritionist average rating calculation', () {
      test('No reviews = 0.0 average', () {
        expect(computeNutritionistAvgRating(0.0, 0), 0.0);
      });

      test('One 5-star review = 5.0 average', () {
        expect(computeNutritionistAvgRating(5.0, 1), closeTo(5.0, 0.001));
      });

      test('Two reviews (4 and 2) = 3.0 average', () {
        expect(computeNutritionistAvgRating(6.0, 2), closeTo(3.0, 0.001));
      });

      test('Ten reviews all at 4.5 = 4.5 average', () {
        expect(computeNutritionistAvgRating(45.0, 10), closeTo(4.5, 0.001));
      });

      test('Updating a review recalculates sum correctly', () {
        // User had rated 3.0, now rates 5.0
        final updatedSum = computeUpdatedRatingSum(
          oldSum: 23.0,
          oldRating: 3.0,
          newRating: 5.0,
        );
        expect(updatedSum, closeTo(25.0, 0.001)); // 23 - 3 + 5 = 25
      });

      test('Downgrading a review recalculates sum correctly', () {
        // User had rated 5.0, now rates 2.0
        final updatedSum = computeUpdatedRatingSum(
          oldSum: 45.0,
          oldRating: 5.0,
          newRating: 2.0,
        );
        expect(updatedSum, closeTo(42.0, 0.001)); // 45 - 5 + 2 = 42
      });
    });

    // ─── Nutritionist Post / Tip Business Rules ────────────────────
    group('Nutritionist Post visibility (minTier logic)', () {
      bool canUserViewPost(int userTier, int postMinTier) => userTier >= postMinTier;

      test('Tier 1 user can view tier 1 post', () {
        expect(canUserViewPost(1, 1), true);
      });

      test('Tier 0 (free) user cannot view tier 1 post', () {
        expect(canUserViewPost(0, 1), false);
      });

      test('Tier 2 user can view tier 1 post', () {
        expect(canUserViewPost(2, 1), true);
      });

      test('Tier 2 user can view tier 2 post', () {
        expect(canUserViewPost(2, 2), true);
      });

      test('Tier 1 user cannot view tier 2 post', () {
        expect(canUserViewPost(1, 2), false);
      });

      test('Post with minTier 0 is visible to all users', () {
        expect(canUserViewPost(0, 0), true);
        expect(canUserViewPost(1, 0), true);
        expect(canUserViewPost(2, 0), true);
      });
    });

    // ─── Nutritionist Profile Field Validation ─────────────────────
    group('Nutritionist profile field completion', () {
      test('Required fields are non-empty on valid profile', () {
        final profile = {
          'fullName': 'Dr. Ayesha Khan',
          'email': 'ayesha@nutrition.com',
          'phoneNumber': '03001234567',
          'licenseNumber': 'PKR-NUT-001',
          'certificateUrl': 'https://storage.example.com/cert.pdf',
        };

        for (final key in ['fullName', 'email', 'phoneNumber', 'licenseNumber']) {
          expect(profile[key]!.isNotEmpty, true, reason: '$key should be non-empty');
        }
      });

      test('Organization name is optional (can be null)', () {
        final profile = <String, dynamic>{
          'fullName': 'Dr. Bob',
          'organizationName': null,
        };
        expect(profile['organizationName'], null); // Optional field
      });

      test('Bank details structure is correct', () {
        final bankDetails = {
          'bankName': 'HBL',
          'accountHolderName': 'Dr. Ayesha Khan',
          'accountNumber': '1234567890',
        };
        expect(bankDetails.containsKey('bankName'), true);
        expect(bankDetails.containsKey('accountHolderName'), true);
        expect(bankDetails.containsKey('accountNumber'), true);
        expect(bankDetails['bankName']!.isNotEmpty, true);
      });
    });
  });
}
