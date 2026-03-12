// ============================================================
// StartupRouter.dart — FINAL ECOSYSTEM-SAFE VERSION
// - Device STATE is authoritative
// - Explicit reset handling (no timing races)
// - No Wi-Fi reset loops possible
// - FIXED: existing numbers with incomplete profile
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';


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

  String cleanId(dynamic v) =>
      v == null ? "" : v.toString().replaceAll('"', '').trim();

  // ============================================================
  // DEVICE ONLINE CHECK
  // ============================================================
  Future<bool> _deviceIsOnline(String deviceId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection("devices")
          .doc(deviceId)
          .get();

      if (!snap.exists) return false;

      final data = snap.data()!;
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

  // ============================================================
  // ROUTING DECISION
  // ============================================================
  Future<String> _decideRoute() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    final now = DateTime.now().millisecondsSinceEpoch;

    // ------------------------------------------------------------
    // WIFI RESET GRACE WINDOW
    // ------------------------------------------------------------
    final wifiResetSent = prefs.getBool("wifiResetSent") ?? false;
    final wifiResetAt = prefs.getInt("wifiResetAt");

    if (wifiResetSent && wifiResetAt != null) {
      final diff = (now - wifiResetAt) ~/ 1000;
      if (diff < 60) return "/wifi-config";
      await prefs.remove("wifiResetSent");
      await prefs.remove("wifiResetAt");
    }

    final seenWelcome = prefs.getBool("seen_welcome") ?? false;
    final needsWifi = prefs.getBool("needsWifiSetup") ?? true;
    String pairedDevice = prefs.getString("pairedDevice") ?? "";

    if (!seenWelcome) return "/welcome";

    // ------------------------------------------------------------
    // LOGOUT
    // ------------------------------------------------------------
    if (user == null) {
      await prefs.remove("pairedDevice");
      await prefs.remove("wifiLock");
      await prefs.remove("wifiResetSent");
      await prefs.remove("wifiResetAt");
      return "/phone-auth";
    }

    // ------------------------------------------------------------
    // CAREGIVER PROFILE CHECK (🔥 CRITICAL FIX)
    // ------------------------------------------------------------
    final cgSnap = await FirebaseFirestore.instance
        .collection("caregivers")
        .doc(user.uid)
        .get();

    if (!cgSnap.exists) return "/caregiver-info";

    final data = cgSnap.data()!;

    final hasName =
        data["name"] != null && data["name"].toString().trim().isNotEmpty;

    final hasEmergency =
        data["emergencyName"] != null &&
        data["emergencyPhone"] != null &&
        data["emergencyName"].toString().trim().isNotEmpty &&
        data["emergencyPhone"].toString().trim().isNotEmpty;

    // 🚨 FORCE COMPLETION EVEN FOR EXISTING NUMBERS
    if (!hasName || !hasEmergency) {
      return "/caregiver-info";
    }

    // ------------------------------------------------------------
    // DEVICE PAIRING
    // ------------------------------------------------------------
    if (pairedDevice.isEmpty) {
      final devices =
          (data["devices"] as List?)?.cast<String>() ?? [];

      if (devices.isEmpty) return "/device-pairing";

      pairedDevice = devices.first;
      await prefs.setString("pairedDevice", pairedDevice);
    }

    // ------------------------------------------------------------
    // DEVICE RESET STATE
    // ------------------------------------------------------------
    final deviceSnap = await FirebaseFirestore.instance
        .collection("devices")
        .doc(pairedDevice)
        .get();

    if (deviceSnap.exists &&
        deviceSnap.data()?["status"] == "resetting") {
      return "/wifi-config";
    }

    // ------------------------------------------------------------
    // WIFI CHECK (NON-BLOCKING)
    // ------------------------------------------------------------
    if (needsWifi) {
      final online = await _deviceIsOnline(pairedDevice);

      if (online) {
        await prefs.setBool("needsWifiSetup", false);
        await prefs.remove("wifiLock");
        await prefs.remove("wifiResetSent");
        await prefs.remove("wifiResetAt");
      }

      return "/dashboard";
    }

    return "/dashboard";
  }

 

  // ============================================================
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
      Navigator.pushReplacementNamed(context, route);

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