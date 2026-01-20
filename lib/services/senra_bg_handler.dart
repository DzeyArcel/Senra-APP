import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../firebase_options.dart';

/// ============================================================
/// 🔔 SENRA BACKGROUND HANDLER (PRODUCTION SAFE)
/// ============================================================
/// ❗ DO NOT show notifications here
/// ❗ DO NOT use flutter_local_notifications here
/// ❗ Android SYSTEM handles background & killed notifications
/// ============================================================
@pragma('vm:entry-point')
Future<void> senraBgHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Intentionally empty
  // Notification is handled by Android system
}
