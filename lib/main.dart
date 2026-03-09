import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'startup_router.dart';

// 🔔 Background handler
import 'services/senra_bg_handler.dart';

// 🔔 Notification channel
import 'services/notification_channel.dart';

// Screens
import 'screens/welcome_screen.dart';
import 'screens/phone_auth_screen.dart';
import 'screens/caregiver_info_screen.dart';
import 'screens/device_pairing_screen.dart';
import 'screens/device_found_screen.dart';
import 'screens/device_connected_screen.dart';
import 'screens/connecting_to_senra_screen.dart';
import 'screens/wifi_config_screen.dart';
import 'screens/all_set_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/manage_device_screen.dart';
import 'screens/edit_account_info_screen.dart';
import 'screens/emergency_contacts_screen.dart';
import 'screens/edit_contact_screen.dart';
import 'screens/location_tracking_screen.dart';
import 'screens/activity_history_screen.dart';
import 'screens/alert_screen.dart';
import 'screens/help_notified_screen.dart';
import 'screens/waiting_for_ap_screen.dart';


final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 Firebase init
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 🔔 REQUIRED for background & killed notifications
  FirebaseMessaging.onBackgroundMessage(senraBgHandler);

  // 🔔 REQUIRED notification channel
  await setupNotificationChannel();

  // 🔔 Android 13+ permission
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // 🔔 Foreground heads-up permission
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  // ============================================================
  // 🔥 FCM TOKEN REGISTER & REFRESH (CRITICAL — SAFE)
  // ============================================================
  final messaging = FirebaseMessaging.instance;

  // Get current token
  final token = await messaging.getToken();
  debugPrint("📲 FCM TOKEN: $token");

  if (token != null) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection("caregivers")
          .doc(user.uid)
          .update({
        "fcmToken": token,
      });

      debugPrint("✅ FCM token saved");
    }
  }

  // Listen for token refresh
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    debugPrint("🔁 FCM token refreshed: $newToken");

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection("caregivers")
          .doc(user.uid)
          .update({
        "fcmToken": newToken,
      });

      debugPrint("✅ Refreshed token saved");
    }
  });

  runApp(const SenraApp());
}

class SenraApp extends StatelessWidget {
  const SenraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,

      // 🔥 StartupRouter runs ONCE
      initialRoute: '/startup',

      // ============================================================
      // STATIC ROUTES
      // ============================================================
      routes: {
        '/startup': (_) => const StartupRouter(),
        '/welcome': (_) => const WelcomeScreen(),
        '/phone-auth': (_) => const PhoneAuthScreen(),
        '/caregiver-info': (_) => const CaregiverInfoScreen(),

        // 🔗 DEVICE FLOW
        '/device-pairing': (_) => const DevicePairingScreen(),
        '/device-found': (_) => const DeviceFoundScreen(),
        '/device-connected': (_) => const DeviceConnectedScreen(),
        '/connecting-senra': (_) => const ConnectingToSenraScreen(),
        '/waiting-ap': (_) => const WaitingForAP(),
        '/wifi-config': (_) => const WifiConfigScreen(),
        '/all-set': (_) => const AllSetScreen(),

        // 🏠 MAIN
        '/dashboard': (_) => const DashboardScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/manage-device': (_) => const ManageDeviceScreen(),
        '/edit-account': (_) => const EditAccountInfoScreen(),
        '/activity-history': (_) => const ActivityHistoryScreen(),
        '/location-tracking': (_) => const LocationTrackingScreen(),
        '/emergency-contacts': (_) => const EmergencyContactsScreen(),
        '/edit-contact': (_) => const EditContactScreen(),
      },

      // ============================================================
      // DYNAMIC ROUTES (ALERTS)
      // ============================================================
     onGenerateRoute: (settings) {
  if (settings.name == '/alert') {
    final args = settings.arguments as Map<String, dynamic>? ?? {};

    return MaterialPageRoute(
      builder: (_) => AlertScreen(
        alertId: args['alertId'],
        deviceId: args['deviceId'],
        fallType: args['fallType'] ?? 'Fall Detected',
        vibrate: args['vibrate'] ?? true,
        playSound: args['playSound'] ?? true,
        showLocation: args['showLocation'] ?? true,
        startSeconds: args['startSeconds'] ?? 30,
      ),
    );
  }

  if (settings.name == '/help-notified') {
    return MaterialPageRoute(
      builder: (_) => const HelpNotifiedScreen(),
    );
  }

  return null;
}
    );
  }
}