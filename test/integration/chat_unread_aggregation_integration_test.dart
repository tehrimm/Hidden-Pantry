import 'package:flutter_test/flutter_test.dart';

class NotificationItem {
  final String type;
  final String targetId;
  final DateTime time;
  NotificationItem(this.type, this.targetId, this.time);
}

class UnreadState {
  final int nutritionistUnread;
  final int userUnread;
  const UnreadState(this.nutritionistUnread, this.userUnread);
}

UnreadState onMessageArrived(UnreadState s, {required bool fromNutritionist}) =>
    fromNutritionist ? UnreadState(s.nutritionistUnread, s.userUnread + 1) : UnreadState(s.nutritionistUnread + 1, s.userUnread);

UnreadState onViewerOpen(UnreadState s, {required bool isNutritionist}) =>
    isNutritionist ? UnreadState(0, s.userUnread) : UnreadState(s.nutritionistUnread, 0);

List<NotificationItem> aggregate(List<NotificationItem> items, Duration window) {
  items.sort((a, b) => a.time.compareTo(b.time));
  // Collapse by (type,targetId) within window, irrespective of interleaving events
  final Map<String, NotificationItem> latestByKey = {};
  for (final n in items) {
    final key = '${n.type}::${n.targetId}';
    final prev = latestByKey[key];
    if (prev == null) {
      latestByKey[key] = n;
      continue;
    }
    if (n.time.difference(prev.time) <= window) {
      // extend window cluster
      latestByKey[key] = NotificationItem(n.type, n.targetId, n.time);
    } else {
      // start a new cluster; to preserve ordering, emit the old one as distinct by adding suffix to key
      latestByKey['$key@${n.time.microsecondsSinceEpoch}'] = n;
    }
  }
  final out = latestByKey.values.toList();
  out.sort((a, b) => a.time.compareTo(b.time));
  return out;
}

void main() {
  group('Integration: Chat unread + notification aggregation', () {
    test('Unread count increments and resets correctly', () {
      var s = UnreadState(0, 0);
      s = onMessageArrived(s, fromNutritionist: true);  // user +1
      s = onMessageArrived(s, fromNutritionist: false); // nutr +1
      expect(s.userUnread, 1);
      expect(s.nutritionistUnread, 1);
      s = onViewerOpen(s, isNutritionist: false); // user opens
      expect(s.userUnread, 0);
      expect(s.nutritionistUnread, 1);
    });

    test('Aggregation collapses consecutive similar notifications', () {
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      final items = [
        NotificationItem('like', 'post_1', t0),
        NotificationItem('like', 'post_1', t0.add(const Duration(minutes: 3))),
        NotificationItem('comment', 'post_1', t0.add(const Duration(minutes: 4))),
        NotificationItem('like', 'post_2', t0.add(const Duration(minutes: 1))),
      ];
      final out = aggregate(items, const Duration(minutes: 5));
      // two 'like/post_1' collapse; 'comment/post_1' and 'like/post_2' remain
      expect(out.length, 3);
      final pairs = out.map((e) => '${e.type}/${e.targetId}').toSet();
      expect(pairs.contains('like/post_1'), true);
      expect(pairs.contains('comment/post_1'), true);
      expect(pairs.contains('like/post_2'), true);
    });
  });
}
