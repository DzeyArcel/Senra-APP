import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin _plugin =
    FlutterLocalNotificationsPlugin();

Future<void> setupNotificationChannel() async {
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'senra_alerts', // MUST MATCH CLOUD FUNCTION
    'Senra Emergency Alerts',
    description: 'Fall detection and emergency alerts',
    importance: Importance.high,
    playSound: true,
  );

  await _plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}
