import 'package:flutter_test/flutter_test.dart';

class Thread {
  final String id;
  final int unreadForUser;
  final int unreadForNutr;
  const Thread(this.id, this.unreadForUser, this.unreadForNutr);
}

Thread openByUser(Thread t) => Thread(t.id, 0, t.unreadForNutr);
Thread openByNutr(Thread t) => Thread(t.id, t.unreadForUser, 0);

List<Thread> markAllReadByUser(List<Thread> threads) =>
    threads.map(openByUser).toList();

void main() {
  group('Integration: Chat mark-all-read across threads', () {
    test('Opening a thread resets viewer-specific unread', () {
      final t = Thread('c1', 5, 2);
      final after = openByUser(t);
      expect(after.unreadForUser, 0);
      expect(after.unreadForNutr, 2);
    });
    test('Mark all read clears all user unread counts', () {
      final threads = [
        Thread('c1', 3, 0),
        Thread('c2', 1, 5),
      ];
      final cleared = markAllReadByUser(threads);
      expect(cleared.every((t) => t.unreadForUser == 0), true);
      expect(cleared.first.unreadForNutr, 0);
      expect(cleared.last.unreadForNutr, 5);
    });
  });
}

