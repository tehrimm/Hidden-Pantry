// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:hidden_pantry_app/features/onboarding/screens/starting_screen.dart';
import 'firebase_options.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hidden_pantry_app/core/services/fcm_service.dart';
import 'package:hidden_pantry_app/core/services/navigation_service.dart';
import 'package:hidden_pantry_app/core/services/notification_service.dart';
import 'package:hidden_pantry_app/features/user/services/iap_service.dart';
import 'package:hidden_pantry_app/core/services/user_status_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Set the background messaging handler early on, as a named top-level function
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize FCM
  final fcmService = FCMService();
  try {
    // Don't strongly await it or it can freeze emulators without Google Play Services
    fcmService.initialize().catchError((e) {
      print("FCM Init Non-fatal Error: $e");
    });
  } catch (e) {
    print("FCM Service could not be initialized: $e");
  }

  // App Check (fixes: "No AppCheckProvider installed")
  // Use PlayIntegrity (Android) and DeviceCheck (iOS) to stop Debug quota exhaustion which causes "Too many attempts" errors.
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.deviceCheck,
    );
  } catch (e) {
    print("AppCheck Init Non-fatal Error: $e");
  }

  // Initialize In-App Purchases is handled in initState of HiddenPantryApp
  
  runApp(const HiddenPantryApp());
}

class HiddenPantryApp extends StatefulWidget {
  const HiddenPantryApp({super.key});

  @override
  State<HiddenPantryApp> createState() => _HiddenPantryAppState();
}

class _HiddenPantryAppState extends State<HiddenPantryApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Start global notification listener for foreground sounds/vibration
    NotificationService().startGlobalListener();
    // Initialize In-App Purchases
    IAPService().initialize();
    _hideSystemUI();
    UserStatusService().updateStatus(true);
  }

  void _hideSystemUI() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-apply when user returns to the app (Android drops immersive on swipe)
    if (state == AppLifecycleState.resumed) {
      _hideSystemUI();
      UserStatusService().updateStatus(true);
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.detached) {
      UserStatusService().updateStatus(false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hidden Pantry',
      navigatorKey: NavigationService().navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Satoshi',
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
      ),
      home: const StartingScreen(),
    );
  }
}
