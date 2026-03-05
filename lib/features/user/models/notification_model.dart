import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  like,
  comment,
  reply,
  follow,
  chat_message,
  nutritionist_post,
}

class AppNotification {
  final String id;
  final String recipientId;
  final String senderId;
  final String senderName;
  final String? senderPhotoUrl;
  final String title;
  final String body;
  final NotificationType type;
  final String? targetId; // e.g., recipeId, postId, chatId
  final DateTime timestamp;
  final bool isRead;

  AppNotification({
    required this.id,
    required this.recipientId,
    required this.senderId,
    required this.senderName,
    this.senderPhotoUrl,
    required this.title,
    required this.body,
    required this.type,
    this.targetId,
    required this.timestamp,
    this.isRead = false,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      recipientId: data['recipientId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'Someone',
      senderPhotoUrl: data['senderPhotoUrl'],
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      type: _parseType(data['type']),
      targetId: data['targetId'],
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['read'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'recipientId': recipientId,
      'senderId': senderId,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      'title': title,
      'body': body,
      'type': type.name,
      'targetId': targetId,
      'timestamp': FieldValue.serverTimestamp(),
      'read': isRead,
    };
  }

  static NotificationType _parseType(String? type) {
    switch (type) {
      case 'like': return NotificationType.like;
      case 'comment': return NotificationType.comment;
      case 'reply': return NotificationType.reply;
      case 'follow': return NotificationType.follow;
      case 'chat_message': return NotificationType.chat_message;
      case 'nutritionist_post': return NotificationType.nutritionist_post;
      default: return NotificationType.like;
    }
  }
}
