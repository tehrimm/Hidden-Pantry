import 'package:flutter_test/flutter_test.dart';

List<String> filterFeed(List<String> authorIds, Set<String> blocked) =>
    authorIds.where((a) => !blocked.contains(a.toLowerCase())).toList();

List<String> filterDiscovery(List<String> authorIds, Set<String> blocked) =>
    authorIds.where((a) => !blocked.contains(a.toLowerCase())).toList();

List<String> filterSavedAuthors(List<String> authorIds, Set<String> blocked) =>
    authorIds.where((a) => !blocked.contains(a.toLowerCase())).toList();

void main() {
  group('Integration: Block cascade across views', () {
    test('Blocking an author removes their items from feed, discovery, and saved views', () {
      final feed = ['a1', 'a2', 'A3'];
      final discovery = ['a3', 'a4', 'a1'];
      final saved = ['A3', 'a5'];
      final blocked = {'a3'}.toSet();
      final f1 = filterFeed(feed, blocked);
      final d1 = filterDiscovery(discovery, blocked);
      final s1 = filterSavedAuthors(saved, blocked);
      expect(f1.contains('A3'), false);
      expect(d1.contains('a3'), false);
      expect(s1.contains('A3'), false);
    });
  });
}

