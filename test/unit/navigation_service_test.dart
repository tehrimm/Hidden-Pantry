import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/services/navigation_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  group('NavigationService Tests', () {
    test('navigatorKey should be initialized', () {
      final service = NavigationService();
      expect(service.navigatorKey, isNotNull);
      expect(service.navigatorKey, isA<GlobalKey<NavigatorState>>());
    });

    test('navigatorKey provides access to currentContext', () {
      final service = NavigationService();
      // Without pumping a widget, the context should be null
      expect(service.navigatorKey.currentContext, isNull);
    });

    test('navigatorKey provides access to currentState', () {
      final service = NavigationService();
      // Without pumping a widget, the state should be null
      expect(service.navigatorKey.currentState, isNull);
    });
  });
}
