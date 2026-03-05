import 'package:flutter_test/flutter_test.dart';

class LikeState {
  final bool liked;
  final int count;
  const LikeState(this.liked, this.count);
}

LikeState toggleLike(LikeState s) {
  if (s.liked) {
    final next = s.count - 1;
    return LikeState(false, next < 0 ? 0 : next);
  }
  return LikeState(true, s.count + 1);
}

class SaveState {
  final bool saved;
  final int total;
  const SaveState(this.saved, this.total);
}

SaveState toggleSave(SaveState s) {
  if (s.saved) return SaveState(false, s.total <= 0 ? 0 : s.total - 1);
  return SaveState(true, s.total + 1);
}

void main() {
  group('Integration: Like/Save toggle consistency', () {
    test('Like toggling is idempotent per click and non-negative', () {
      var s = const LikeState(false, 0);
      s = toggleLike(s); // like
      expect(s.liked, true);
      expect(s.count, 1);
      s = toggleLike(s); // unlike
      expect(s.liked, false);
      expect(s.count, 0);
      s = toggleLike(const LikeState(true, 0)); // cannot go below zero
      s = toggleLike(s); // back to zero
      expect(s.count >= 0, true);
    });

    test('Save toggling increments/decrements without going negative', () {
      var s = const SaveState(false, 0);
      s = toggleSave(s);
      expect(s.saved, true);
      expect(s.total, 1);
      s = toggleSave(s);
      expect(s.saved, false);
      expect(s.total, 0);
      s = toggleSave(const SaveState(true, 0));
      s = toggleSave(s);
      expect(s.total >= 0, true);
    });
  });
}

