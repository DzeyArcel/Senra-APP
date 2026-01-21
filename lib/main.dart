import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'startup_router.dart';

// 🔔 Background handler
import 'services/senra_bg_handler.dart';

// 🔔 Notification channel
import 'services/notification_channel.dart';

// Screens
import 'screens/welcome_screen.dart';
import 'screens/phone_auth_screen.dart'; // ✅ ADDED
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

  // 🔔 FOREGROUND LISTENER (LOG ONLY)
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint("📲 FOREGROUND MESSAGE: ${message.notification?.title}");
  });

  // 🔔 APP OPENED FROM BACKGROUND
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint("📲 OPENED FROM BACKGROUND");
  });

  // 🔔 APP OPENED FROM KILLED STATE
  final RemoteMessage? initialMessage =
      await FirebaseMessaging.instance.getInitialMessage();

  if (initialMessage != null) {
    debugPrint("📲 OPENED FROM KILLED STATE");
  }

  runApp(const SenraApp());
}

class SenraApp extends StatelessWidget {
  const SenraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,

      // ============================================================
      // DYNAMIC ROUTES
      // ============================================================
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/alert':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            return MaterialPageRoute(
   builder: (_) => AlertScreen(
  alertId: args['alertId'],
  deviceId: args['deviceId'],
  fallType: args['fallType'] ?? 'Fall Detected',

  // 🔥 DECISIONS PASSED IN
  vibrate: args['vibrate'] ?? true,
  playSound: args['playSound'] ?? true,
  showLocation: args['showLocation'] ?? true,

  lat: args['lat'] != null ? double.tryParse(args['lat'].toString()) : null,
  lng: args['lng'] != null ? double.tryParse(args['lng'].toString()) : null,
  locationLabel: args['locationLabel'] ?? '',
  startSeconds: args['startSeconds'] ?? 30,
),

            );

          case '/help-notified':
            return MaterialPageRoute(
              builder: (_) => const HelpNotifiedScreen(),
            );

          default:
            return null;
        }
      },

      // ============================================================
      // STATIC ROUTES
      // ============================================================
      routes: {
        '/startup': (_) => const StartupRouter(),
        '/welcome': (_) => const WelcomeScreen(),

        // 🔐 AUTH (NEW)
        '/phone-auth': (_) => const PhoneAuthScreen(),

        // 👤 PROFILE
        '/caregiver-info': (_) => const CaregiverInfoScreen(),

        // 🔗 DEVICE FLOW
        '/device-pairing': (_) => const DevicePairingScreen(),
        '/device-found': (_) => const DeviceFoundScreen(),
        '/device-connected': (_) => const DeviceConnectedScreen(),
        '/connecting-senra': (_) => const ConnectingToSenraScreen(),
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

      home: const StartupRouter(),
    );
  }
}
