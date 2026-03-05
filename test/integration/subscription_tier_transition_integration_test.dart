import 'package:flutter_test/flutter_test.dart';

class Content {
  final String id;
  final int minTier;
  Content(this.id, this.minTier);
}

List<Content> visibleContent(List<Content> all, int userTier) =>
    all.where((c) => userTier >= c.minTier).toList();

void main() {
  group('Integration: Subscription tier transition', () {
    test('Upgrade reveals previously gated items without hiding existing ones', () {
      final all = [
        Content('c1', 0),
        Content('c2', 1),
        Content('c3', 2),
      ];
      final at0 = visibleContent(all, 0).map((c) => c.id).toList();
      expect(at0, ['c1']);
      final at1 = visibleContent(all, 1).map((c) => c.id).toList();
      expect(at1, ['c1', 'c2']);
      final at2 = visibleContent(all, 2).map((c) => c.id).toList();
      expect(at2, ['c1', 'c2', 'c3']);
    });
  });
}

