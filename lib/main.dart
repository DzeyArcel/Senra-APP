import 'package:flutter/material.dart';
import 'package:senra_app/screens/activity_history_screen.dart';
import 'package:senra_app/screens/alert_screen.dart';
import 'package:senra_app/screens/dashboard_screen.dart';
import 'package:senra_app/screens/edit_account_info_screen.dart';
import 'package:senra_app/screens/edit_contact_screen.dart';
import 'package:senra_app/screens/emergency_contacts_screen.dart';
import 'package:senra_app/screens/help_notified_screen.dart';
import 'package:senra_app/screens/location_tracking_screen.dart';
import 'package:senra_app/screens/manage_device_screen.dart';
import 'package:senra_app/screens/settings_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/caregiver_info_screen.dart';
import 'screens/device_pairing_screen.dart';
import 'screens/device_found_screen.dart';
import 'screens/device_connected_screen.dart';
import 'screens/connecting_to_senra_screen.dart';
import 'screens/wifi_config_screen.dart';
import 'screens/all_set_screen.dart';

void main() {
  runApp(const SenraApp());
}

class SenraApp extends StatelessWidget {
  const SenraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // ROUTES (Complete flow, nothing renamed)
      routes: {
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


'/alert': (_) => const AlertScreen(location: "Unknown", startSeconds: 3),
  '/help-notified': (_) => const HelpNotifiedScreen(location: "Unknown", contacts: []),



      },

      home: const WelcomeScreen(),
    );
  }
}
