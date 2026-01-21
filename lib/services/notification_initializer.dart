import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../main.dart';


class NotificationInitializer {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static String _currentCaregiverId = "";

  static const String _channelId = 'senra_alerts_v2';

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
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      final AndroidNotificationChannel channel = AndroidNotificationChannel(
        _channelId,
        'Senra Emergency Alerts',
        description: 'Critical fall and emergency alerts from Senra',
        importance: Importance.max,
        enableVibration: true,
        vibrationPattern:
            Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
        playSound: true,
      );

      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await _registerToken();

    _listenForeground();
    _listenBackgroundTap();
    await _listenKilledTap();
  }

  // ============================================================
  // 🔔 NOTIFICATION TAP (ALL STATES)
  // ============================================================
  static Future<void> _onNotificationTap(
      NotificationResponse response) async {
    final alertId = response.payload;
    if (alertId == null || alertId.isEmpty) return;

    await _navigateToAlertFromId(alertId);
  }

  static void _listenBackgroundTap() {
    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      final alertId = message.data['alertId'];
      if (alertId == null) return;

      await _navigateToAlertFromId(alertId);
    });
  }

  static Future<void> _listenKilledTap() async {
    final msg = await FirebaseMessaging.instance.getInitialMessage();
    if (msg != null && msg.data['alertId'] != null) {
      await _navigateToAlertFromId(msg.data['alertId']);
    }
  }

  // ============================================================
  // 🧠 CENTRAL ALERT NAVIGATION (KEY FIX)
  // ============================================================
  static Future<void> _navigateToAlertFromId(String alertId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 🔥 LOAD ALERT
    final alertSnap = await FirebaseFirestore.instance
        .collection('alerts')
        .doc(alertId)
        .get();

    if (!alertSnap.exists) return;

    final alert = alertSnap.data()!;
    final deviceId = alert['deviceId'];
    if (deviceId == null) return;

    // 🔥 LOAD CAREGIVER PREFS
    final caregiverSnap = await FirebaseFirestore.instance
        .collection('caregivers')
        .doc(user.uid)
        .get();

    final caregiver = caregiverSnap.data() ?? {};

    final vibrate = caregiver['emergencyVibration'] ?? true;
    final playSound = caregiver['pushNotifications'] ?? true;
    final showLocation = caregiver['locationSharing'] ?? true;

    navigatorKey.currentState?.pushReplacementNamed(
      '/alert',
      arguments: {
        'alertId': alertId,
        'deviceId': deviceId,
        'fallType': alert['fallType'] ?? 'Fall Detected',

        // 🔥 DECISIONS
        'vibrate': vibrate,
        'playSound': playSound,
        'showLocation': showLocation,

        // 🔥 LOCATION
        'lat': alert['lat'],
        'lng': alert['lng'],
        'locationLabel': alert['location'] ?? '',
        'startSeconds': 30,
      },
    );
  }

  // ============================================================
  // 🔄 TOKEN REGISTRATION
  // ============================================================
  static Future<void> _registerToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    await _saveToken(token);

    FirebaseMessaging.instance.onTokenRefresh.listen(_saveToken);
  }

  static Future<void> _saveToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    final caregiverId =
        _currentCaregiverId.isNotEmpty ? _currentCaregiverId : user?.uid;

    if (caregiverId == null) return;

    await FirebaseFirestore.instance
        .collection('caregivers')
        .doc(caregiverId)
        .set({
      'fcmToken': token,
      'fcmPlatform': Platform.isAndroid ? 'android' : 'ios',
      'fcmUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ============================================================
  // 📩 FOREGROUND NOTIFICATION
  // ============================================================
  static void _listenForeground() {
    FirebaseMessaging.onMessage.listen(showForegroundNotification);
  }

  static Future<void> showForegroundNotification(
      RemoteMessage message) async {
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _channelId,
      'Senra Emergency Alerts',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      message.notification?.title ?? '🚨 Fall Detected',
      message.notification?.body ?? 'Immediate attention required',
      NotificationDetails(android: androidDetails),
      payload: message.data['alertId']?.toString(),
    );
  }

  // ============================================================
  // ⚙ PUSH TOGGLE
  // ============================================================
  static Future<void> updatePushPreference(bool enabled) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('caregivers')
        .doc(user.uid)
        .set({'pushNotifications': enabled}, SetOptions(merge: true));
  }

  static void clearCaregiverContext() {
    _currentCaregiverId = "";
  }
}
