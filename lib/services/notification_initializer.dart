import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';


import '../main.dart';

class NotificationInitializer {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static String _currentCaregiverId = "";

  // ============================================================
  // 🔔 GLOBAL INIT
  // ============================================================
  static Future<void> init({required String caregiverId}) async {
    _currentCaregiverId = caregiverId;

    if (!_initialized) {
      _initialized = true;

      const AndroidInitializationSettings androidInit =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initSettings =
          InitializationSettings(android: androidInit);

      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {
          final alertId = details.payload;
          if (alertId != null && alertId.isNotEmpty) {
            navigatorKey.currentState?.pushNamed(
              '/alert',
              arguments: {'alertId': alertId},
            );
          }
        },
      );

      // 🔔 ANDROID 8+ NOTIFICATION CHANNEL (REQUIRED)
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'senra_alerts',
        'Senra Emergency Alerts',
        description: 'Critical fall and emergency alerts from Senra',
        importance: Importance.max,
      );

      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    // 🔐 ANDROID 13+ PERMISSION
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await _registerToken();
    _listenForeground();
    _listenBackgroundTap();
    _listenKilledTap();
  }

  // ============================================================
  // 🧠 BACKGROUND HANDLER (SYSTEM HANDLES NOTIFICATION)
  // ============================================================
  @pragma('vm:entry-point')
  static Future<void> handleBackground(RemoteMessage message) async {
    await Firebase.initializeApp();
    // ❗ DO NOTHING HERE
    // Android system displays the notification automatically
  }

  // ============================================================
  // 🔄 TOKEN REGISTRATION (CRITICAL FIX HERE)
  // ============================================================
  static Future<void> _registerToken() async {
    final token = await FirebaseMessaging.instance.getToken();

    if (token == null) {
      debugPrint("❌ FCM token is null");
      return;
    }

    debugPrint("📲 FCM TOKEN RECEIVED: $token");

    await _saveToken(token);

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      debugPrint("🔄 FCM TOKEN REFRESHED: $newToken");
      await _saveToken(newToken);
    });
  }

  static Future<void> _saveToken(String token) async {
    if (_currentCaregiverId.isEmpty) {
      debugPrint("❌ caregiverId empty, cannot save FCM token");
      return;
    }

    debugPrint("✅ Saving FCM token for caregiver: $_currentCaregiverId");

    await FirebaseFirestore.instance
        .collection('caregivers')
        .doc(_currentCaregiverId)
        .set({
      'fcmToken': token,
      'fcmPlatform': Platform.isAndroid ? 'android' : 'ios',
      'fcmUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ============================================================
  // 📩 FOREGROUND LISTENER (APP OPEN)
  // ============================================================
  static void _listenForeground() {
    FirebaseMessaging.onMessage.listen((message) {
      showForegroundNotification(message);
    });
  }

  // ============================================================
  // 📬 BACKGROUND TAP (APP IN BACKGROUND)
  // ============================================================
  static void _listenBackgroundTap() {
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      navigatorKey.currentState?.pushNamed(
        '/alert',
        arguments: message.data,
      );
    });
  }

  // ============================================================
  // 🧨 KILLED TAP (APP TERMINATED)
  // ============================================================
  static Future<void> _listenKilledTap() async {
    final msg = await FirebaseMessaging.instance.getInitialMessage();
    if (msg != null) {
      navigatorKey.currentState?.pushNamed(
        '/alert',
        arguments: msg.data,
      );
    }
  }

  // ============================================================
  // 🔔 FOREGROUND NOTIFICATION DISPLAY
  // ============================================================
  static Future<void> showForegroundNotification(
      RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'senra_alerts',
      'Senra Emergency Alerts',
      channelDescription: 'Fall and emergency alerts',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const NotificationDetails details =
        NotificationDetails(android: androidDetails);

    final title = message.notification?.title ?? '🚨 Fall Detected';
    final body =
        message.notification?.body ?? 'Immediate attention required';

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: message.data['alertId']?.toString(),
    );
  }

  // ============================================================
  // ⚙ PUSH NOTIFICATION USER PREFERENCE
  // ============================================================
  static Future<void> updatePushPreference(bool enabled) async {
    if (_currentCaregiverId.isEmpty) return;

    await FirebaseFirestore.instance
        .collection('caregivers')
        .doc(_currentCaregiverId)
        .set({
      'pushNotifications': enabled,
      'pushUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
