import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin _plugin =
    FlutterLocalNotificationsPlugin();

Future<void> setupNotificationChannel() async {
  // 🔧 Initialize plugin
  const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings =
      InitializationSettings(android: androidInit);

  await _plugin.initialize(initSettings);

  // 🔔 Create emergency notification channel
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'senra_alerts_v3', // MUST MATCH CLOUD FUNCTION
    'Senra Emergency Alerts',
    description: 'Fall detection and emergency alerts',
    importance: Importance.max,
    playSound: true,
  );

  await _plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

// 🔔 Show local notification (used when app is in foreground)
Future<void> showLocalNotification({
  required String title,
  required String body,
  String? payload,
}) async {
  const AndroidNotificationDetails androidDetails =
      AndroidNotificationDetails(
    'senra_alerts_v3',
    'Senra Emergency Alerts',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
  );

  const NotificationDetails details =
      NotificationDetails(android: androidDetails);

  await _plugin.show(
    0,
    title,
    body,
    details,
    payload: payload,
  );
}