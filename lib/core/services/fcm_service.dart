import 'dart:typed_data';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hidden_pantry_app/features/nutritionist/services/nutritionist_service.dart';
import 'package:hidden_pantry_app/features/user/services/user_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hidden_pantry_app/core/services/notification_service.dart';
import 'package:hidden_pantry_app/features/user/models/notification_model.dart';
import 'package:hidden_pantry_app/core/services/navigation_service.dart';
// Removed unused Flutter Material import

class FCMService {
  final _messaging = FirebaseMessaging.instance;
  final _nutritionistService = NutritionistService();
  final _userService = UserService();

  final _localNotif = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // 1. Android Notification Channel (High Importance)
    final AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
    );

    await _localNotif
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 2. Initialize Local Notifications
    final initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    final initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    
    await _localNotif.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          _handleDeepLink(details.payload!);
        }
      },
    );

    // 3. Request Permission
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    }

    // 4. Get Token
    String? token = await _messaging.getToken();
    if (token != null) {
      _saveTokenToDatabase(token);
    }

    _messaging.onTokenRefresh.listen(_saveTokenToDatabase);

    // 5. Handle Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        _localNotif.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: android.smallIcon,
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
          payload: "${message.data['type'] ?? ''}|${message.data['id'] ?? ''}|${message.data['senderId'] ?? ''}",
        );
      }
    });

    // 6. Handle Background/Terminated state taps
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleDeepLinkFromMessage(message);
    });

    // Initial message if app was terminated
    _messaging.getInitialMessage().then((message) {
      if (message != null) {
        _handleDeepLinkFromMessage(message);
      }
    });
  }

  void _handleDeepLinkFromMessage(RemoteMessage message) {
    final payload = "${message.data['type'] ?? ''}|${message.data['id'] ?? ''}|${message.data['senderId'] ?? ''}";
    if (message.data['type'] != null) { // Check if type is present before handling
       _handleDeepLink(payload);
    }
  }

  void _handleDeepLink(String payload) {
    // Parsing payload like "chat_message|chat_123|sender_uid"
    final parts = payload.split('|');
    final typeStr = parts[0];
    final id = parts.length > 1 ? parts[1] : "";
    final senderId = parts.length > 2 ? parts[2] : "";

    if (id.isEmpty) return;

    // Use NotificationService's navigation logic but via global key
    final context = NavigationService().navigatorKey.currentContext;
    if (context == null) return;

    // Map string type back to enum
    NotificationType? type;
    try {
      type = NotificationType.values.firstWhere((e) => e.name == typeStr);
    } catch (_) {}

    if (type != null) {
      final notif = AppNotification(
        id: "temp",
        recipientId: "", 
        senderId: senderId,
        senderName: "User", // Placeholder
        title: "",
        body: "",
        type: type,
        timestamp: DateTime.now(),
        targetId: id,
      );
      NotificationService().navigateByNotification(context, notif);
    }
  }

  Future<void> _saveTokenToDatabase(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Check if user is a nutritionist
      final nutritionistProfile = await _nutritionistService.getNutritionistProfile(user.uid);
      
      if (nutritionistProfile != null) {
        await _nutritionistService.updateFCMToken(token);
        print("FCM Token saved to nutritionists collection.");
      } else {
        await _userService.updateFCMToken(token);
        print("FCM Token saved to users collection.");
      }
    } catch (e) {
      print("Error saving FCM token: $e");
    }
  }
}



