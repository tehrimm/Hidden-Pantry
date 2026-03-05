import 'package:flutter_test/flutter_test.dart';

class UnreadState {
  final int nutritionistUnread;
  final int userUnread;
  const UnreadState(this.nutritionistUnread, this.userUnread);
}

UnreadState onMessageArrived({
  required bool fromNutritionist,
  required UnreadState state,
}) {
  if (fromNutritionist) {
    // Increment user's unread
    return UnreadState(state.nutritionistUnread, state.userUnread + 1);
  } else {
    // Increment nutritionist's unread
    return UnreadState(state.nutritionistUnread + 1, state.userUnread);
  }
}

UnreadState onViewerOpen({
  required bool viewerIsNutritionist,
  required UnreadState state,
}) {
  if (viewerIsNutritionist) {
    return UnreadState(0, state.userUnread);
  } else {
    return UnreadState(state.nutritionistUnread, 0);
  }
}

void main() {
  group('Business: Unread counter rules', () {
    test('User receives message from nutritionist increments userUnread', () {
      final s0 = UnreadState(0, 0);
      final s1 = onMessageArrived(fromNutritionist: true, state: s0);
      expect(s1.userUnread, 1);
      expect(s1.nutritionistUnread, 0);
    });

    test('Nutritionist receives message from user increments nutritionistUnread', () {
      final s0 = UnreadState(0, 0);
      final s1 = onMessageArrived(fromNutritionist: false, state: s0);
      expect(s1.nutritionistUnread, 1);
      expect(s1.userUnread, 0);
    });

    test('Viewer opening chat resets their own unread only', () {
      final s0 = UnreadState(3, 5);
      final s1 = onViewerOpen(viewerIsNutritionist: true, state: s0);
      expect(s1.nutritionistUnread, 0);
      expect(s1.userUnread, 5);

      final s2 = onViewerOpen(viewerIsNutritionist: false, state: s0);
      expect(s2.nutritionistUnread, 3);
      expect(s2.userUnread, 0);
    });
  });
}

