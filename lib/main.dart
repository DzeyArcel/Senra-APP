import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:senra_app/firebase_options.dart';

// Startup Router
import 'startup_router.dart';

// SCREENS
import 'screens/welcome_screen.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const SenraApp());
}

class SenraApp extends StatelessWidget {
  const SenraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // ---------------------------------------------------
      // 🚀 MAIN ROUTE GENERATOR (now supports arguments)
      // ---------------------------------------------------
      onGenerateRoute: (RouteSettings settings) {
        final args = settings.arguments;

        switch (settings.name) {
          case '/alert':
            return MaterialPageRoute(
              builder: (_) => AlertScreen(
                location: (args is Map) ? args["location"] : "Unknown",
              ),
            );

          case '/help-notified':
            return MaterialPageRoute(
              builder: (_) => HelpNotifiedScreen(
                location: (args is Map) ? args["location"] : "Unknown",
                sentTime: (args is Map) ? args["sentTime"] ?? "Unknown" : "Unknown",
                contacts: (args is Map) ? args["contacts"] ?? [] : [],
                lat: (args is Map) ? args["lat"] : null,
                lng: (args is Map) ? args["lng"] : null,
              ),
            );

          default:
            return null;
        }
      },

      // STATIC ROUTES
      routes: {
        '/welcome': (_) => const WelcomeScreen(),
        '/startup': (_) => const StartupRouter(),

        '/caregiver-info': (_) => const CaregiverInfoScreen(),
        '/device-pairing': (_) => const DevicePairingScreen(),
        '/device-found': (_) => const DeviceFoundScreen(),
        '/device-connected': (_) => const DeviceConnectedScreen(),
        '/connecting-senra': (_) => const ConnectingToSenraScreen(),
        '/wifi-config': (_) => const WifiConfigScreen(),
        '/all-set': (_) => const AllSetScreen(),

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
