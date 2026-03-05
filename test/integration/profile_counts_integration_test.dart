import 'package:flutter_test/flutter_test.dart';

class ProfileCounts {
  final int likes;
  final int saves;
  const ProfileCounts(this.likes, this.saves);
}

ProfileCounts applyLike(ProfileCounts c, bool like) {
  if (like) return ProfileCounts(c.likes + 1, c.saves);
  final next = c.likes - 1;
  return ProfileCounts(next < 0 ? 0 : next, c.saves);
}

ProfileCounts applySave(ProfileCounts c, bool save) {
  if (save) return ProfileCounts(c.likes, c.saves + 1);
  final next = c.saves - 1;
  return ProfileCounts(c.likes, next < 0 ? 0 : next);
}

void main() {
  group('Integration: Profile summary like/save counts', () {
    test('Counts reflect toggles and remain non-negative', () {
      var s = const ProfileCounts(0, 0);
      s = applyLike(s, true);
      s = applySave(s, true);
      expect(s.likes, 1);
      expect(s.saves, 1);
      s = applyLike(s, false);
      s = applySave(s, false);
      expect(s.likes, 0);
      expect(s.saves, 0);
      s = applyLike(s, false);
      s = applySave(s, false);
      expect(s.likes >= 0 && s.saves >= 0, true);
    });
  });
}

