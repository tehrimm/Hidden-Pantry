// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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

  // 🔒 Lock orientation globally to Portrait only (prevents landscape rotations entirely)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // // Disable app verification so Phone OTP works on Android Emulators
  // if (kDebugMode) {
  //   await FirebaseAuth.instance.setSettings(appVerificationDisabledForTesting: true);
  // }

  // ⚡ Enable Firestore offline persistence — reads are served from cache on repeat opens
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
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

  // App Check
  // Use PlayIntegrity (Android) and DeviceCheck (iOS) in release mode
  if (!kDebugMode) {
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.playIntegrity,
        appleProvider: AppleProvider.deviceCheck,
      );
    } catch (e) {
      print("AppCheck Init Non-fatal Error: $e");
    }
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
    // Start global status listener for online/offline tracking
    UserStatusService().startGlobalListener();
    // Initialize In-App Purchases
    IAPService().initialize();
    _hideSystemUI();
    UserStatusService().updateStatus(true);
  }

  void _hideSystemUI() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF462F4D),
          primary: const Color(0xFF462F4D),
          secondary: const Color(0xFFEF8A54),
          surface: const Color(0xFFFFF3EB),
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Color(0xFF462F4D),
          selectionColor: Color(0x33462F4D),
          selectionHandleColor: Color(0xFF462F4D),
        ),
        pageTransitionsTheme: PageTransitionsTheme(
          builders: {
            TargetPlatform.android: const ZoomPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.linux: const FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: const FadeUpwardsPageTransitionsBuilder(),
          },
        ),
      ),
      home: const StartingScreen(),
    );
  }
}
