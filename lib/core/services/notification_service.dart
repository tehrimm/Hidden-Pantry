import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/features/user/models/notification_model.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/features/recipes/screens/recipe_details.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_service.dart';
import 'package:hidden_pantry_app/features/nutritionist/screens/nutritionist_details.dart';
import 'package:hidden_pantry_app/features/nutritionist/screens/chat_interface_part.dart';
import 'package:hidden_pantry_app/features/user/screens/my_subscriptions.dart';
class NotificationService {
  final FirebaseFirestore _firestore;
  final AudioPlayer _player;

  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService({FirebaseFirestore? firestore, AudioPlayer? audioPlayer}) {
    if (firestore != null || audioPlayer != null) {
      return NotificationService._(
        firestore ?? FirebaseFirestore.instance,
        audioPlayer ?? AudioPlayer(),
      );
    }
    return _instance;
  }
  
  NotificationService._internal() 
      : _firestore = FirebaseFirestore.instance,
        _player = AudioPlayer();

  NotificationService._(this._firestore, this._player);

  // For foreground alert tracking
  String? _lastNotifId;
  StreamSubscription? _notifSubscription;
  StreamSubscription? _authSubscription;

  /// Starts a global auth listener that manages notification listening
  void startGlobalListener() {
    _authSubscription?.cancel();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _startNotificationSubscription();
      } else {
        _notifSubscription?.cancel();
        _lastNotifId = null;
      }
    });
  }

  void _startNotificationSubscription() {
    _notifSubscription?.cancel();
    _notifSubscription = streamNotifications().listen((notifications) {
      if (notifications.isNotEmpty) {
        final latest = notifications.first;
        // Check if unread and it's a new ID
        if (!latest.isRead && latest.id != _lastNotifId) {
          _lastNotifId = latest.id;
          // Only alert if the notification is recent (e.g., within last 30 seconds)
          // to prevent buzzing for old unread notifications on login
          final age = DateTime.now().difference(latest.timestamp).inSeconds.abs();
          if (age < 30) {
            playNotificationSound();
          }
        }
      }
    });
  }

  void stopGlobalListener() {
    _authSubscription?.cancel();
    _notifSubscription?.cancel();
  }

  /// Logs a notification to Firestore and prepares for FCM push
  Future<void> sendNotification({
    required String recipientId,
    required String title,
    required String body,
    required NotificationType type,
    String? targetId,
    bool playSound = true,
    String? recipientRole, 
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || recipientId == user.uid) return;

    final notification = {
      'recipientId': recipientId,
      'senderId': user.uid,
      'senderName': user.displayName ?? 'Someone',
      'senderPhotoUrl': user.photoURL,
      'title': title,
      'body': body,
      'type': type.name,
      'targetId': targetId,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    };

    try {
      String collectionName = 'users'; 
      String? fcmToken;

      // 1. Determine collection & Fetch FCM Token
      if (recipientRole == 'nutritionist') {
        collectionName = 'nutritionists';
        final doc = await _firestore.collection('nutritionists').doc(recipientId).get();
        fcmToken = doc.data()?['fcmToken'];
      } else if (recipientRole == 'user') {
        collectionName = 'users';
        final doc = await _firestore.collection('users').doc(recipientId).get();
        fcmToken = doc.data()?['fcmToken'];
      } else {
        // Fallback role check
        final nutDoc = await _firestore.collection('nutritionists').doc(recipientId).get();
        if (nutDoc.exists) {
          collectionName = 'nutritionists';
          fcmToken = nutDoc.data()?['fcmToken'];
        } else {
          collectionName = 'users';
          final userDoc = await _firestore.collection('users').doc(recipientId).get();
          fcmToken = userDoc.data()?['fcmToken'];
        }
      }

      // 2. Save to Firestore for in-app history/listeners
      await _firestore
          .collection(collectionName)
          .doc(recipientId)
          .collection('notifications')
          .add(notification);
      
      print("[NotificationService] Notification saved to $collectionName/$recipientId. FCM Token: ${fcmToken != null ? 'Present' : 'Missing'}");

      // 3. Trigger Remote Push if token exists
      if (fcmToken != null) {
        print("[NotificationService] Real FCM Push trigger would be sent here for token: $fcmToken");
      }
    } catch (e) {
      print("[NotificationService] Error sending notification: $e");
    }
  }

  /// Notifies all followers and active subscribers of a nutritionist about a new post
  Future<void> notifyFollowersOfPost({
    required String nutritionistId,
    required String nutritionistName,
    required String? nutritionistPhotoUrl,
    required String content,
    required String postId,
  }) async {
    try {
      final Set<String> recipientIds = {};

      // 1. Fetch all followers (from users/{id}/followers)
      final followersSnap = await _firestore
          .collection('users')
          .doc(nutritionistId)
          .collection('followers')
          .get();
      for (var doc in followersSnap.docs) {
        recipientIds.add(doc.id);
      }

      // 2. Fetch all active subscribers (from global subscriptions collection)
      final subsSnap = await _firestore
          .collection('subscriptions')
          .where('nutritionistId', isEqualTo: nutritionistId)
          .where('status', isEqualTo: 'active')
          .get();
      for (var doc in subsSnap.docs) {
        final userId = doc.data()['userId'] as String?;
        if (userId != null) recipientIds.add(userId);
      }

      final List<Future> notifications = [];
      for (var recipientId in recipientIds) {
        notifications.add(sendNotification(
          recipientId: recipientId,
          title: "New Post from $nutritionistName",
          body: content.length > 50 ? "${content.substring(0, 50)}..." : content,
          type: NotificationType.nutritionist_post,
          targetId: nutritionistId, 
          playSound: false, // Bulk notifications are silent for UX
        ));
      }
      
      await Future.wait(notifications);
      print("[NotificationService] Notified ${recipientIds.length} users (followers + subscribers).");
    } catch (e) {
      print("[NotificationService] Error notifying followers/subscribers: $e");
    }
  }

  /// Streams notifications for the current user
  Stream<List<AppNotification>> streamNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);

    // Check if the user is a nutritionist to decide which collection to listen to
    return _firestore.collection('nutritionists').doc(user.uid).snapshots().asyncExpand((nutDoc) {
      // Use nutritionist collection if doc exists, else use users collection
      final collectionName = nutDoc.exists ? 'nutritionists' : 'users';
      
      return _firestore
          .collection(collectionName)
          .doc(user.uid)
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snap) => snap.docs.map((doc) => AppNotification.fromFirestore(doc)).toList());
    });
  }

  /// Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final nutDoc = await _firestore.collection('nutritionists').doc(user.uid).get();
    final collectionName = nutDoc.exists ? 'nutritionists' : 'users';

    await _firestore
        .collection(collectionName)
        .doc(user.uid)
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }

  /// Mark all notifications for a specific target (e.g., chat) as read
  Future<void> markNotificationsForTargetAsRead(String targetId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final nutDoc = await _firestore.collection('nutritionists').doc(user.uid).get();
    final collectionName = nutDoc.exists ? 'nutritionists' : 'users';

    final snapshots = await _firestore
        .collection(collectionName)
        .doc(user.uid)
        .collection('notifications')
        .where('targetId', isEqualTo: targetId)
        .where('read', isEqualTo: false)
        .get();

    if (snapshots.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (var doc in snapshots.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final nutDoc = await _firestore.collection('nutritionists').doc(user.uid).get();
    final collectionName = nutDoc.exists ? 'nutritionists' : 'users';

    await _firestore
        .collection(collectionName)
        .doc(user.uid)
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }

  /// Play a notification sound and vibrate
  Future<void> playNotificationSound() async {
    try {
      await _player.play(UrlSource('https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3'));
      // Add vibration
      await HapticFeedback.vibrate();
    } catch (e) {
      print("Error playing sound or vibrating: $e");
    }
  }

  /// Navigates to the relevant screen based on notification type
  Future<void> navigateByNotification(BuildContext context, AppNotification notif) async {
    if (notif.targetId == null || notif.targetId!.isEmpty) return;

    switch (notif.type) {
      case NotificationType.chat_message:
        // When navigating to chat from a notification:
        // notif.targetId is the chatId
        // notif.senderId is the person who sent it (the client for the nutritionist)
        Navigator.push(context, MaterialPageRoute(builder: (context) => ChatInterface(
          nutritionistId: FirebaseAuth.instance.currentUser?.uid ?? "",
          nutritionistData: const {}, 
          chatIdOverride: notif.targetId,
          clientId: notif.senderId, // Propagate the sender of the notification as the client
          otherUserName: notif.senderName, // Pass the name so the heading is correct
          otherUserPhoto: notif.senderPhotoUrl,
        )));
        break;
      case NotificationType.like:
      case NotificationType.comment:
      case NotificationType.reply:
        // Fetch full recipe to navigate
        Recipe? recipe = await RecipeService().getRecipeById(notif.targetId!);
        
        // Robust Fallback: If not found, targetId might be a reviewId (older notifications)
        if (recipe == null) {
          try {
            final reviewDoc = await FirebaseFirestore.instance.collection('reviews').doc(notif.targetId).get();
            if (reviewDoc.exists) {
              final recipeId = reviewDoc.data()?['recipeId'];
              if (recipeId != null) {
                recipe = await RecipeService().getRecipeById(recipeId);
              }
            }
          } catch (_) {}
        }

        if (recipe != null && context.mounted) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => RecipeDetailsScreen(recipe: recipe!)));
        }
        break;
      case NotificationType.follow:
        // Navigate to public profile - requires PublicProfileScreen implementation
        break;
      case NotificationType.nutritionist_post:
        // Navigate to nutritionist profile (user view)
        // targetId is the nutritionistId
        final nutDoc = await _firestore.collection('nutritionists').doc(notif.targetId).get();
        if (nutDoc.exists && context.mounted) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => NutritionistDetailsScreen(
            nutritionistId: notif.targetId!,
            nutritionistData: nutDoc.data() ?? {},
          )));
        }
        break;
      case NotificationType.subscription_alert:
        Navigator.push(context, MaterialPageRoute(builder: (context) => MySubscriptionsScreen()));
        break;
      case NotificationType.admin_alert:
        // Admin warnings are informational only — no navigation needed
        break;
    }
  }
}
