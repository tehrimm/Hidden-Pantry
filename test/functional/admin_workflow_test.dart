import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hidden_pantry_app/features/admin/screens/admin_certificate_review.dart';
import 'package:hidden_pantry_app/features/nutritionist/services/nutritionist_service.dart';
import 'package:mockito/mockito.dart';
import 'mock_firebase.dart';
import 'test_utils.dart';

import 'dart:async';

class ManualMockNutritionistService extends Mock implements NutritionistService {
  List<Map<String, dynamic>> pendingExperts = [
    {'uid': 'exp1', 'fullName': 'Dr. Healthy', 'email': 'healthy@test.com', 'isCertificateVerified': false},
    {'uid': 'exp2', 'fullName': 'Chef Salad', 'email': 'salad@test.com', 'isCertificateVerified': false},
  ];

  late final StreamController<List<Map<String, dynamic>>> _controller;

  ManualMockNutritionistService() {
    _controller = StreamController<List<Map<String, dynamic>>>.broadcast(
      onListen: () {
        _controller.add(pendingExperts);
      },
    );
  }

  @override
  Stream<List<Map<String, dynamic>>> getPendingNutritionists() {
    return _controller.stream;
  }

  @override
  Future<void> approveNutritionist(String uid) async {
    pendingExperts.removeWhere((e) => e['uid'] == uid);
    _controller.add(pendingExperts);
  }

  @override
  Future<void> rejectNutritionist(String uid, String reason) async {
    pendingExperts.removeWhere((e) => e['uid'] == uid);
    _controller.add(pendingExperts);
  }

  void close() {
    _controller.close();
  }
}

void main() {
  setUpAll(() async {
    setupFirebaseAuthMocks();
    await Firebase.initializeApp();
    setUpNetworkImageMock();
  });

  Widget wrap(Widget child) => MaterialApp(home: child);

  void setupScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
  }

  void resetScreen(WidgetTester tester) {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  group('Admin Workflow Functional Tests', () {
    testWidgets('Admin can review and approve certificates', (tester) async {
      setupScreen(tester);
      addTearDown(() => resetScreen(tester));
      final mockService = ManualMockNutritionistService();
      
      await tester.pumpWidget(wrap(AdminCertificateReviewScreen(nutritionistService: mockService)));
      await tester.pumpAndSettle();

      // 1. Verify list of pending experts
      expect(find.text('Dr. Healthy'), findsOneWidget);
      expect(find.text('Chef Salad'), findsOneWidget);

      // 2. Approve Dr. Healthy
      // Finding the 'Approve' button specifically for 'Dr. Healthy'
      final approveButton = find.descendant(
        of: find.ancestor(of: find.text('Dr. Healthy'), matching: find.byWidgetPredicate((w) => w is Container)),
        matching: find.text('Approve'),
      ).first;
      
      await tester.tap(approveButton);
      await tester.pumpAndSettle(); // Dialog appears

      // Tap Approve in Dialog
      final dialogApproveBtn = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Approve'),
      );
      await tester.tap(dialogApproveBtn);
      await tester.pumpAndSettle(); // Settle the list change

      // 3. Verify Dr. Healthy is gone
      expect(find.text('Dr. Healthy'), findsNothing);
      expect(find.text('Chef Salad'), findsOneWidget);
    });

    testWidgets('Admin see empty state when no pending experts', (tester) async {
      setupScreen(tester);
      addTearDown(() => resetScreen(tester));
      final mockService = ManualMockNutritionistService();
      mockService.pendingExperts = []; // Clear list
      
      await tester.pumpWidget(wrap(AdminCertificateReviewScreen(nutritionistService: mockService)));
      await tester.pumpAndSettle();

      expect(find.text('No pending experts'), findsOneWidget);
    });

  });
}
