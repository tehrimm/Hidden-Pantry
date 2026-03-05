import 'package:flutter_test/flutter_test.dart';

class NotificationItem {
  final String type; // e.g., like, comment, follow
  final String targetId; // post/user id
  final DateTime timestamp;
  NotificationItem(this.type, this.targetId, this.timestamp);
}

List<NotificationItem> aggregateNotifications(
  List<NotificationItem> items, {
  Duration window = const Duration(minutes: 5),
}) {
  items.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  final List<NotificationItem> out = [];
  for (final n in items) {
    if (out.isEmpty) {
      out.add(n);
      continue;
    }
    final last = out.last;
    final sameTarget = last.type == n.type && last.targetId == n.targetId;
    final withinWindow = n.timestamp.difference(last.timestamp) <= window;
    if (sameTarget && withinWindow) {
      // Collapse: keep latest timestamp
      out[out.length - 1] = NotificationItem(last.type, last.targetId, n.timestamp);
    } else {
      out.add(n);
    }
  }
  return out;
}

void main() {
  group('Business: Notification aggregation', () {
    test('Collapses same type/target in window', () {
      final t0 = DateTime(2024, 1, 1, 12, 0, 0);
      final items = [
        NotificationItem('like', 'p1', t0),
        NotificationItem('like', 'p1', t0.add(const Duration(minutes: 2))),
        NotificationItem('like', 'p1', t0.add(const Duration(minutes: 4, seconds: 59))),
      ];
      final out = aggregateNotifications(items);
      expect(out.length, 1);
      expect(out.first.timestamp, t0.add(const Duration(minutes: 4, seconds: 59)));
    });

    test('Different type or target not collapsed', () {
      final t0 = DateTime(2024, 1, 1, 12, 0, 0);
      final items = [
        NotificationItem('like', 'p1', t0),
        NotificationItem('comment', 'p1', t0.add(const Duration(minutes: 1))),
        NotificationItem('like', 'p2', t0.add(const Duration(minutes: 2))),
      ];
      final out = aggregateNotifications(items);
      expect(out.length, 3);
    });

    test('Outside window creates new entry', () {
      final t0 = DateTime(2024, 1, 1, 12, 0, 0);
      final items = [
        NotificationItem('like', 'p1', t0),
        NotificationItem('like', 'p1', t0.add(const Duration(minutes: 6))),
      ];
      final out = aggregateNotifications(items);
      expect(out.length, 2);
    });
  });
}

