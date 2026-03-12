// ============================================================
// StartupRouter.dart — CLEAN STABLE VERSION
// - Auth check first
// - Safe onboarding routing
// - Device state authority
// - No WiFi reset loops
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
  StreamSubscription? netSub;

  bool routed = false;
  bool isOffline = false;

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
    final now = DateTime.now().millisecondsSinceEpoch;

    final user = FirebaseAuth.instance.currentUser;

    // ------------------------------------------------------------
    // AUTH CHECK FIRST
    // ------------------------------------------------------------

    if (user == null) {
      await prefs.remove("pairedDevice");
      return "/phone-auth";
    }

    // ------------------------------------------------------------
    // WELCOME SCREEN
    // ------------------------------------------------------------

    final seenWelcome = prefs.getBool("seen_welcome") ?? false;
    if (!seenWelcome) return "/welcome";

    // ------------------------------------------------------------
    // WIFI RESET GRACE WINDOW
    // ------------------------------------------------------------

    final wifiResetSent = prefs.getBool("wifiResetSent") ?? false;
    final wifiResetAt = prefs.getInt("wifiResetAt");

    if (wifiResetSent && wifiResetAt != null) {
      final diff = (now - wifiResetAt) ~/ 1000;

      if (diff < 60) {
        return "/wifi-config";
      }

      await prefs.remove("wifiResetSent");
      await prefs.remove("wifiResetAt");
    }

    // ------------------------------------------------------------
    // CAREGIVER PROFILER
    // ------------------------------------------------------------

    final cgRef =
        FirebaseFirestore.instance.collection("caregivers").doc(user.uid);

    final cgSnap = await cgRef.get();
    
if (!cgSnap.exists) {
  await FirebaseAuth.instance.signOut();
  return "/phone-auth";
}

    final data = cgSnap.data()!;

    final hasName =
        data["name"] != null && data["name"].toString().trim().isNotEmpty;

    if (!hasName) {
      return "/caregiver-info";
    }

    final hasEmergency =
        data["emergencyName"] != null &&
        data["emergencyPhone"] != null &&
        data["emergencyName"].toString().trim().isNotEmpty &&
        data["emergencyPhone"].toString().trim().isNotEmpty;

    if (!hasEmergency) {
      return "/emergency-contacts";
    }

    // ------------------------------------------------------------
    // DEVICE PAIRING
    // ------------------------------------------------------------

    String pairedDevice = prefs.getString("pairedDevice") ?? "";

    if (pairedDevice.isEmpty) {
      final devices = (data["devices"] as List?)?.cast<String>() ?? [];

      if (devices.isEmpty) {
        return "/device-pairing";
      }

      pairedDevice = devices.first;

      await prefs.setString("pairedDevice", pairedDevice);
    }

    // ------------------------------------------------------------
    // DEVICE RESET
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
    // WIFI CHECK
    // ------------------------------------------------------------

    final needsWifi = prefs.getBool("needsWifiSetup") ?? true;

    if (needsWifi) {
      final online = await _deviceIsOnline(pairedDevice);

      if (online) {
        await prefs.setBool("needsWifiSetup", false);
      }
    }

    return "/dashboard";
  }

  // ============================================================

  @override
  void initState() {
    super.initState();

    netSub = Connectivity().onConnectivityChanged.listen((result) {
      setState(() {
        isOffline = result == ConnectivityResult.none;
      });
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
    netSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0E1625),
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFF33B5FF),
        ),
      ),
    );
  }
}