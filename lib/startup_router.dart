// ============================================================
// StartupRouter.dart — FINAL ECOSYSTEM-SAFE VERSION
// - Device STATE is authoritative
// - Explicit reset handling (no timing races)
// - No Wi-Fi reset loops possible
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../services/notification_initializer.dart';

class StartupRouter extends StatefulWidget {
  const StartupRouter({super.key});

  @override
  State<StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<StartupRouter> {
  StreamSubscription? alertSub;
  StreamSubscription? netSub;

  bool alertOpened = false;
  bool routed = false;
  bool isOffline = false;

  // ------------------------------------------------------------
  String cleanId(dynamic v) =>
      v == null ? "" : v.toString().replaceAll('"', '').trim();

  // ------------------------------------------------------------
  // 🔑 DEVICE ONLINE CHECK — STATE AWARE (CRITICAL FIX)
  // ------------------------------------------------------------
  Future<bool> _deviceIsOnline(String deviceId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection("devices")
          .doc(deviceId)
          .get();

      if (!snap.exists) return false;

      final data = snap.data()!;

      // 🚫 Explicit transition state
      if (data["status"] == "resetting") return false;

      final ts = data["lastSync"];
      DateTime? lastSync;

      if (ts is Timestamp) lastSync = ts.toDate();
      if (ts is String) lastSync = DateTime.tryParse(ts);

      if (lastSync == null) return false;

      return DateTime.now().difference(lastSync).inSeconds < 40;
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------
  Future<String> _decideRoute() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;

    final now = DateTime.now().millisecondsSinceEpoch;

    // =========================================================
    // 🚨 ABSOLUTE PRIORITY — WIFI RESET GRACE WINDOW
    // =========================================================
    final wifiResetSent = prefs.getBool("wifiResetSent") ?? false;
    final wifiResetAt = prefs.getInt("wifiResetAt");

    if (wifiResetSent && wifiResetAt != null) {
      final diff = (now - wifiResetAt) ~/ 1000;

      if (diff < 60) {
        debugPrint("⏳ WiFi reset grace window ($diff s)");
        return "/wifi-config";
      } else {
        await prefs.remove("wifiResetSent");
        await prefs.remove("wifiResetAt");
      }
    }

    final seenWelcome = prefs.getBool("seen_welcome") ?? false;
    final needsWifi = prefs.getBool("needsWifiSetup") ?? true;
    String pairedDevice = prefs.getString("pairedDevice") ?? "";

    if (!seenWelcome) return "/welcome";
    if (user == null) return "/phone-auth";

    final cgSnap = await FirebaseFirestore.instance
        .collection("caregivers")
        .doc(user.uid)
        .get();

    if (!cgSnap.exists) return "/caregiver-info";

    if (pairedDevice.isEmpty) {
      final devices =
          (cgSnap.data()?["devices"] as List?)?.cast<String>() ?? [];

      if (devices.isEmpty) return "/device-pairing";

      pairedDevice = devices.first;
      await prefs.setString("pairedDevice", pairedDevice);
    }

    // =========================================================
    // 🔒 DEVICE STATE CHECK (RESETTING → FORCE WIFI CONFIG)
    // =========================================================
    final deviceSnap = await FirebaseFirestore.instance
        .collection("devices")
        .doc(pairedDevice)
        .get();

    if (deviceSnap.exists) {
      final status = deviceSnap.data()?["status"];
      if (status == "resetting") {
        debugPrint("🟠 Device resetting → forcing WiFi config");
        return "/wifi-config";
      }
    }

    // =========================================================
    // 🚫 NEVER SKIP WIFI CONFIG UNTIL DEVICE IS ONLINE
    // =========================================================
    if (needsWifi) {
  final online = await _deviceIsOnline(pairedDevice);

  if (online) {
    await prefs.setBool("needsWifiSetup", false);
    await prefs.remove("wifiLock");
    await prefs.remove("wifiResetSent");
    await prefs.remove("wifiResetAt");

    debugPrint("✅ WiFi confirmed → dashboard");
  } else {
    debugPrint("⚠️ Device offline → dashboard (offline state)");
  }

  // 🚀 ALWAYS allow dashboard access
  return "/dashboard";
}

    // =========================================================
    // ✅ NORMAL FLOW
    // =========================================================
    final online = await _deviceIsOnline(pairedDevice);
    return "/dashboard";
  }

  // ------------------------------------------------------------
  Future<void> _listenForAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;
    if (prefs.getBool("wifiLock") == true) return;

    final pairedDevice = prefs.getString("pairedDevice") ?? "";
    if (pairedDevice.isEmpty) return;

    await NotificationInitializer.init();


    alertSub = FirebaseFirestore.instance
        .collection("alerts")
        .snapshots()
        .listen((snap) {
      if (snap.docs.isEmpty || alertOpened || isOffline) return;

      final valid = snap.docs.where((d) {
        final ts = d.data()["timestamp"];
        return ts is Timestamp || ts is String;
      }).toList();

      valid.sort((a, b) {
        DateTime ta =
            (a.data()["timestamp"] as Timestamp?)?.toDate() ??
                DateTime.tryParse(a.data()["timestamp"] ?? "") ??
                DateTime(1970);

        DateTime tb =
            (b.data()["timestamp"] as Timestamp?)?.toDate() ??
                DateTime.tryParse(b.data()["timestamp"] ?? "") ??
                DateTime(1970);

        return tb.compareTo(ta);
      });

      for (final doc in valid) {
        final data = doc.data();
        if (cleanId(data["deviceId"]) != pairedDevice) continue;
        if (data["delivered"] == true) continue;

        alertOpened = true;
        Navigator.pushReplacementNamed(
          context,
          "/alert",
          arguments: {"alertId": doc.id},
        );
        break;
      }
    });
  }

  // ------------------------------------------------------------
  @override
  void initState() {
    super.initState();

    netSub = Connectivity().onConnectivityChanged.listen((r) {
      setState(() => isOffline = r == ConnectivityResult.none);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final route = await _decideRoute();
      if (!mounted || routed) return;

      routed = true;
      debugPrint("🚦 StartupRouter routing → $route");
      Navigator.pushReplacementNamed(context, route);

      if (route != "/wifi-config") {
        _listenForAlerts();
      }
    });
  }

  @override
  void dispose() {
    alertSub?.cancel();
    netSub?.cancel();
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
