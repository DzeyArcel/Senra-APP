import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../main.dart';

class NotificationInitializer {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  // 🔒 Prevent duplicate alert openings
  static String? _activeAlertId;
  static bool _alertNavigationLock = false;

  // TEXT ONLY CHANNEL
  static const String _channelId = 'senra_text_alerts_v1';

  // ============================================================
  // GLOBAL INIT
  // ============================================================
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      'Senra Alerts',
      description: 'Text notifications for fall alerts',
      importance: Importance.high,
      playSound: false,
      enableVibration: false,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: false,
    );

    await _registerAndHealToken();

    // LISTENERS
    _listenForeground();
    _listenFirestoreAlerts();
    _listenBackgroundTap();
    await _listenKilledTap();
  }

  // ============================================================
  // TOKEN REGISTER
  // ============================================================
  static Future<void> _registerAndHealToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    await FirebaseFirestore.instance
        .collection('caregivers')
        .doc(user.uid)
        .set({
      'fcmToken': token,
      'fcmPlatform': Platform.isAndroid ? 'android' : 'ios',
      'pushNotifications': true,
      'fcmUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      await FirebaseFirestore.instance
          .collection('caregivers')
          .doc(user.uid)
          .set({
        'fcmToken': newToken,
        'fcmPlatform': Platform.isAndroid ? 'android' : 'ios',
        'pushNotifications': true,
        'fcmUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  // ============================================================
  // TAP EVENTS
  // ============================================================
  static Future<void> _onNotificationTap(
      NotificationResponse response) async {
    final alertId = response.payload;
    if (alertId == null || alertId.isEmpty) return;

    await _navigateToAlert(alertId);
  }

  static void _listenBackgroundTap() {
    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      final alertId = message.data['alertId'];
      if (alertId == null) return;

      await _navigateToAlert(alertId);
    });
  }

  static Future<void> _listenKilledTap() async {
    final msg = await FirebaseMessaging.instance.getInitialMessage();
    if (msg != null && msg.data['alertId'] != null) {
      await _navigateToAlert(msg.data['alertId']);
    }
  }

  // ============================================================
  // NAVIGATION
  // ============================================================
  static Future<void> _navigateToAlert(String alertId) async {
    if (_alertNavigationLock) return;
    if (_activeAlertId == alertId) return;

    _alertNavigationLock = true;
    _activeAlertId = alertId;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _alertNavigationLock = false;
      return;
    }

    final alertSnap = await FirebaseFirestore.instance
        .collection('alerts')
        .doc(alertId)
        .get();

    if (!alertSnap.exists) {
      _alertNavigationLock = false;
      return;
    }

    final alert = alertSnap.data()!;
    final deviceId = alert['deviceId'];
    if (deviceId == null) {
      _alertNavigationLock = false;
      return;
    }

    final caregiverSnap = await FirebaseFirestore.instance
        .collection('caregivers')
        .doc(user.uid)
        .get();

    final caregiver = caregiverSnap.data() ?? {};

    navigatorKey.currentState?.pushReplacementNamed(
      '/alert',
      arguments: {
        'alertId': alertId,
        'deviceId': deviceId,
        'fallType': alert['fallType'] ?? 'Fall Detected',
        'vibrate': caregiver['emergencyVibration'] ?? true,
        'playSound': caregiver['pushNotifications'] ?? true,
        'showLocation': caregiver['locationSharing'] ?? true,
        'lat': alert['lat'],
        'lng': alert['lng'],
        'locationLabel': alert['location'] ?? '',
        'startSeconds': 30,
      },
    );

    Future.delayed(const Duration(seconds: 2), () {
      _alertNavigationLock = false;
    });
  }

  // ============================================================
  // FOREGROUND NOTIFICATION
  // ============================================================
  static void _listenForeground() {
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
  }

  static Future<void> _showForegroundNotification(
      RemoteMessage message) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('caregivers')
        .doc(user.uid)
        .get();

    if (!snap.exists) return;

    final caregiver = snap.data()!;
    if (caregiver['pushNotifications'] == false) return;

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _channelId,
      'Senra Alerts',
      channelDescription: 'Text notifications for fall alerts',
      importance: Importance.high,
      priority: Priority.high,
      playSound: false,
      enableVibration: false,
      category: AndroidNotificationCategory.message,
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      message.notification?.title ?? '🚨 Fall Detected',
      message.notification?.body ??
          'Possible fall detected. Open Senra to respond.',
      NotificationDetails(android: androidDetails),
      payload: message.data['alertId']?.toString(),
    );
  }

  // ============================================================
  // FIRESTORE ALERT LISTENER
  // ============================================================
  static void _listenFirestoreAlerts() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('alerts')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {

      for (final doc in snapshot.docs) {
        final data = doc.data();

        if (data['caregiverId'] != user.uid) continue;

        final alertId = doc.id;

        if (_activeAlertId == alertId) return;

        _navigateToAlert(alertId);
      }

    });
  }

  // ============================================================
  // PUSH PREFERENCE
  // ============================================================
  static Future<void> updatePushPreference(bool enabled) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('caregivers')
        .doc(user.uid)
        .set({
      'pushNotifications': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ============================================================
  // CLEAR ACTIVE ALERT (called when alert screen closes)
  // ============================================================
  static void clearActiveAlert() {
    _activeAlertId = null;
  }
}