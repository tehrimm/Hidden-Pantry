import 'package:flutter_test/flutter_test.dart';

enum EntryScreen { wrapperForNutritionist, mainShellForUser, loadingOne }

EntryScreen entryRoute({
  required bool isAuthenticated,
  required bool isNutritionist,
}) {
  if (!isAuthenticated) return EntryScreen.loadingOne;
  if (isNutritionist) return EntryScreen.wrapperForNutritionist;
  return EntryScreen.mainShellForUser;
}

void main() {
  group('Business: App entry routing', () {
    test('Unauthenticated goes to LoadingOne', () {
      final s = entryRoute(isAuthenticated: false, isNutritionist: false);
      expect(s, EntryScreen.loadingOne);
    });
    test('Authenticated nutritionist goes to Wrapper', () {
      final s = entryRoute(isAuthenticated: true, isNutritionist: true);
      expect(s, EntryScreen.wrapperForNutritionist);
    });
    test('Authenticated user goes to Main Shell', () {
      final s = entryRoute(isAuthenticated: true, isNutritionist: false);
      expect(s, EntryScreen.mainShellForUser);
    });
  });
}

