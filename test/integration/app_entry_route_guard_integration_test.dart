import 'package:flutter_test/flutter_test.dart';

enum RouteName { login, verify, home }

RouteName appEntryRoute({required bool loggedIn, required bool emailVerified}) {
  if (!loggedIn) return RouteName.login;
  if (!emailVerified) return RouteName.verify;
  return RouteName.home;
}

void main() {
  group('Integration: App entry route guard', () {
    test('Routes to login when not authenticated', () {
      expect(appEntryRoute(loggedIn: false, emailVerified: false), RouteName.login);
    });
    test('Routes to verify when logged in but not verified', () {
      expect(appEntryRoute(loggedIn: true, emailVerified: false), RouteName.verify);
    });
    test('Routes to home when authenticated and verified', () {
      expect(appEntryRoute(loggedIn: true, emailVerified: true), RouteName.home);
    });
  });
}

