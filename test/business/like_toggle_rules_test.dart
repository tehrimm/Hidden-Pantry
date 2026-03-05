import 'package:flutter_test/flutter_test.dart';

class LikeState {
  final Set<String> likers;
  const LikeState(this.likers);
}

bool canToggleLike({
  required bool viewerIsNutritionist,
  required bool isLocked,
  required bool idsPresent,
}) {
  if (viewerIsNutritionist) return false;
  if (isLocked) return false;
  if (!idsPresent) return false;
  return true;
}

LikeState toggleLike({
  required LikeState state,
  required String userId,
  required bool viewerIsNutritionist,
  required bool isLocked,
  required bool idsPresent,
}) {
  if (!canToggleLike(
    viewerIsNutritionist: viewerIsNutritionist,
    isLocked: isLocked,
    idsPresent: idsPresent,
  )) {
    return state;
  }
  final next = Set<String>.from(state.likers);
  if (next.contains(userId)) {
    next.remove(userId);
  } else {
    next.add(userId);
  }
  return LikeState(next);
}

void main() {
  group('Business: Like toggle rules', () {
    test('Allowed viewer toggles add then remove', () {
      final s0 = LikeState(<String>{});
      final s1 = toggleLike(
        state: s0,
        userId: 'u1',
        viewerIsNutritionist: false,
        isLocked: false,
        idsPresent: true,
      );
      expect(s1.likers.contains('u1'), true);
      final s2 = toggleLike(
        state: s1,
        userId: 'u1',
        viewerIsNutritionist: false,
        isLocked: false,
        idsPresent: true,
      );
      expect(s2.likers.contains('u1'), false);
    });

    test('Disallowed viewer does nothing', () {
      final s0 = LikeState(<String>{});
      final s1 = toggleLike(
        state: s0,
        userId: 'u1',
        viewerIsNutritionist: true,
        isLocked: false,
        idsPresent: true,
      );
      expect(s1.likers.isEmpty, true);
    });

    test('Locked content prevents toggle', () {
      final s0 = LikeState(<String>{});
      final s1 = toggleLike(
        state: s0,
        userId: 'u1',
        viewerIsNutritionist: false,
        isLocked: true,
        idsPresent: true,
      );
      expect(s1.likers.isEmpty, true);
    });

    test('Missing ids prevents toggle', () {
      final s0 = LikeState(<String>{});
      final s1 = toggleLike(
        state: s0,
        userId: 'u1',
        viewerIsNutritionist: false,
        isLocked: false,
        idsPresent: false,
      );
      expect(s1.likers.isEmpty, true);
    });
  });
}

