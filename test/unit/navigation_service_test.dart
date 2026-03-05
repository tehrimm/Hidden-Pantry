import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/services/navigation_service.dart';

void main() {
  group('NavigationService Tests', () {
    test('navigatorKey should be initialized', () {
      final service = NavigationService();
      expect(service.navigatorKey, isNotNull);
      expect(service.navigatorKey, isA<GlobalKey<NavigatorState>>());
    });
  });
}
