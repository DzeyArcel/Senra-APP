// ============================================================
// StartupRouter.dart — FINAL SENRA ROUTER (AUTH-SAFE + DEVICE RECOVERY)
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 🔔 Notification init
import '../services/notification_initializer.dart';

class StartupRouter extends StatefulWidget {
  const StartupRouter({super.key});

  @override
  State<StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<StartupRouter> {
  StreamSubscription? alertSub;
  bool alertOpened = false;
  bool routed = false;

  // ------------------------------------------------------------
  String cleanId(dynamic v) {
    if (v == null) return "";
    return v.toString().replaceAll('"', "").trim();
  }

  // ------------------------------------------------------------
  Future<bool> _deviceIsOnline(String deviceId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection("devices")
          .doc(deviceId)
          .get();

      if (!snap.exists) return false;

      final data = snap.data()!;
      final status = data["status"] ?? "offline";
      final lastSync = (data["lastSync"] as Timestamp?)?.toDate();

      if (lastSync == null) return false;

      final recentlyActive =
          DateTime.now().difference(lastSync).inSeconds < 40;

      return status == "online" && recentlyActive;
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------
  // 🔐 ROUTE DECISION (AUTH FIRST – FIXED)
  // ------------------------------------------------------------
  Future<String> _decideRoute() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;

    final seenWelcome = prefs.getBool("seen_welcome") ?? false;
    String pairedDevice = prefs.getString("pairedDevice") ?? "";
    final needsWifiSetup = prefs.getBool("needsWifiSetup") ?? true;

    // 1️⃣ FIRST TIME USER
    if (!seenWelcome) {
      return "/welcome";
    }

    // 2️⃣ NOT AUTHENTICATED
    if (user == null) {
      return "/phone-auth";
    }

    final caregiverId = user.uid;

    // 3️⃣ CAREGIVER MUST EXIST
    final cgSnap = await FirebaseFirestore.instance
        .collection("caregivers")
        .doc(caregiverId)
        .get();

    if (!cgSnap.exists) {
      return "/caregiver-info";
    }

    final cgData = cgSnap.data() ?? <String, dynamic>{};


    // ------------------------------------------------------------
    // 🔁 DEVICE RECOVERY FROM FIRESTORE (KEY FIX)
    // ------------------------------------------------------------
    if (pairedDevice.isEmpty) {
      final devices =
          (cgData["devices"] as List?)?.map((e) => e.toString()).toList() ?? [];

      if (devices.isNotEmpty) {
        pairedDevice = devices.first;

        await prefs.setString("pairedDevice", pairedDevice);
        await prefs.setBool("needsWifiSetup", false);
      } else {
        await prefs.setBool("needsWifiSetup", true);
        return "/device-pairing";
      }
    }

    // 5️⃣ WIFI NOT FINISHED
    if (needsWifiSetup) {
      return "/connecting-senra";
    }

    // 6️⃣ DEVICE ONLINE?
    final online = await _deviceIsOnline(pairedDevice);

    if (online) {
      await prefs.setBool("needsWifiSetup", false);
      return "/dashboard";
    }

    // 7️⃣ FALLBACK
    return "/connecting-senra";
  }

    // ------------------------------------------------------------
  // 🔔 ALERT LISTENER (PATCHED FOR ALERTSCREEN v2)
  // ------------------------------------------------------------
  Future<void> _listenForAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final pairedDevice = prefs.getString("pairedDevice") ?? "";
    final needsWifiSetup = prefs.getBool("needsWifiSetup") ?? true;

    if (pairedDevice.isEmpty || needsWifiSetup) return;

    // 🔔 init notifications
    await NotificationInitializer.init(caregiverId: user.uid);

    final watchDevice = cleanId(pairedDevice);

    alertSub = FirebaseFirestore.instance
        .collection("alerts")
        .snapshots()
        .listen((snap) async {
      if (snap.docs.isEmpty || alertOpened) return;

      final sorted = List<QueryDocumentSnapshot>.from(snap.docs)
        ..sort((a, b) {
          final ad = a.data() as Map<String, dynamic>;
          final bd = b.data() as Map<String, dynamic>;

          DateTime ta = (ad["timestamp"] is Timestamp)
              ? ad["timestamp"].toDate()
              : DateTime.tryParse(ad["timestamp"].toString()) ??
                  DateTime(2000);

          DateTime tb = (bd["timestamp"] is Timestamp)
              ? bd["timestamp"].toDate()
              : DateTime.tryParse(bd["timestamp"].toString()) ??
                  DateTime(2000);

          return tb.compareTo(ta);
        });

      for (final doc in sorted) {
        final data = doc.data() as Map<String, dynamic>;

        if (cleanId(data["deviceId"]) != watchDevice) continue;
        if (data["delivered"] == true) continue;

        DateTime ts = (data["timestamp"] is Timestamp)
            ? data["timestamp"].toDate()
            : DateTime.tryParse(data["timestamp"].toString()) ??
                DateTime(2000);

        if (DateTime.now().difference(ts).inSeconds > 120) continue;

        // 🔥 LOAD CAREGIVER PREFS ONCE
        final caregiverSnap = await FirebaseFirestore.instance
            .collection("caregivers")
            .doc(user.uid)
            .get();

        final caregiver = caregiverSnap.data() ?? {};

        final vibrate = caregiver["emergencyVibration"] ?? true;
        final playSound = caregiver["pushNotifications"] ?? true;
        final showLocation = caregiver["locationSharing"] ?? true;

        alertOpened = true;

        if (!routed && mounted) {
          routed = true;
          Navigator.pushReplacementNamed(
            context,
            "/alert",
            arguments: {
              "alertId": doc.id,
              "deviceId": watchDevice,
              "fallType": data["fallType"] ?? "Fall Detected",

              // 🔥 DECISIONS
              "vibrate": vibrate,
              "playSound": playSound,
              "showLocation": showLocation,

              // 🔥 LOCATION (ONLY DATA)
              "lat": data["lat"],
              "lng": data["lng"],
              "locationLabel": data["location"] ?? "",
              "startSeconds": 30,
            },
          );
        }

        await FirebaseFirestore.instance
            .collection("alerts")
            .doc(doc.id)
            .update({"delivered": true});

        break;
      }
    });
  }


  // ------------------------------------------------------------
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      final route = await _decideRoute();

      if (!routed && mounted && !alertOpened) {
        routed = true;
        Navigator.pushReplacementNamed(context, route);
      }

      _listenForAlerts(); // AFTER routing
    });
  }

  @override
  void dispose() {
    alertSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0E1625),
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFF33B5FF)),
      ),
    );
  }
}
