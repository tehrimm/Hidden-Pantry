// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:hidden_pantry_app/features/onboarding/screens/starting_screen.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'firebase_options.dart';


import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hidden_pantry_app/core/services/fcm_service.dart';
import 'package:hidden_pantry_app/core/services/navigation_service.dart';
import 'package:hidden_pantry_app/core/services/notification_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

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
  // Use debug provider in development so Storage works without enforcement issues.
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );

  // Initialize Stripe with test publishable key
  // Replace with your real Stripe test publishable key from dashboard.stripe.com
  Stripe.publishableKey = 'pk_test_51T2Ds7ENiugjDkbs5TG3vrHBS0TGhrAKFdEBOOoa7kI1lIQyaI2IqEuFj7rDpp4V1MiiBbVKnVaCKa6gKdZ3lyGQ00IbY2azku';

  runApp(const HiddenPantryApp());
}

class HiddenPantryApp extends StatefulWidget {
  const HiddenPantryApp({super.key});

  @override
  State<HiddenPantryApp> createState() => _HiddenPantryAppState();
}

class _HiddenPantryAppState extends State<HiddenPantryApp> {
  @override
  void initState() {
    super.initState();
    // Start global notification listener for foreground sounds/vibration
    NotificationService().startGlobalListener();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ));
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



