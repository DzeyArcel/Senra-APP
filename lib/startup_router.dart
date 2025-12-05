import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StartupRouter extends StatefulWidget {
  const StartupRouter({super.key});

  @override
  State<StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<StartupRouter> {
  StreamSubscription? alertSub;
  bool alertShown = false;

  // ============================================================
  // DECIDE STARTUP SCREEN — NOW WITH ONBOARDING FLOW SUPPORT
  // ============================================================
  Future<String> _decideRoute() async {
    final prefs = await SharedPreferences.getInstance();

    final caregiverId = prefs.getString("caregiverId");
    final pairedDevice = prefs.getString("pairedDevice");
    final onboarding = prefs.getBool("onboarding_complete") ?? false;

    // -------------------------------------------------
    // 1️⃣ No caregiver → Start from welcome
    // -------------------------------------------------
    if (caregiverId == null || caregiverId.isEmpty) {
      return "/welcome";
    }

    // Check caregiver document
    final caregiverSnap = await FirebaseFirestore.instance
        .collection("caregivers")
        .doc(caregiverId)
        .get();

    if (!caregiverSnap.exists) {
      await prefs.clear();
      return "/welcome";
    }

    // -------------------------------------------------
    // 2️⃣ Caregiver exists but ONBOARDING NOT FINISHED
    // -------------------------------------------------
    if (!onboarding) {
      // Step A – caregiver filled info but no paired device
      if (pairedDevice == null || pairedDevice.isEmpty) {
        return "/device-pairing";
      }

      // Step B – device exists but has not reached "AllSet"
      return "/device-connected";
    }

    // -------------------------------------------------
    // 3️⃣ Onboarding complete → check online status
    // -------------------------------------------------
    if (pairedDevice == null || pairedDevice.isEmpty) {
      return "/dashboard"; // prevent loops
    }

    final deviceSnap = await FirebaseFirestore.instance
        .collection("devices")
        .doc(pairedDevice)
        .get();

    if (!deviceSnap.exists) {
      return "/dashboard";
    }

    final raw = deviceSnap.data() ?? {};

    // ====== ONLINE CHECK (same 20s rule across app) ======
    bool online = false;
    final lastSyncRaw = raw["lastSync"];
    DateTime? lastSync;

    if (lastSyncRaw is Timestamp) {
      lastSync = lastSyncRaw.toDate();
    } else if (lastSyncRaw is String) {
      lastSync = DateTime.tryParse(lastSyncRaw);
    }

    if (lastSync != null) {
      final diff = DateTime.now().difference(lastSync).inSeconds;
      online = diff <= 20;
    }

    return "/dashboard";
  }

  // ============================================================
  // REAL-TIME ALERT LISTENER — Only triggers after onboarding
  // ============================================================
  Future<void> _listenForAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final caregiverId = prefs.getString("caregiverId");
    final pairedDevice = prefs.getString("pairedDevice");
    final onboarding = prefs.getBool("onboarding_complete") ?? false;

    if (!onboarding) return; // do NOT interrupt onboarding

    if (caregiverId == null) return;

    alertSub = FirebaseFirestore.instance
        .collection("alerts")
        .orderBy("timestamp", descending: true)
        .snapshots()
        .listen((snap) {
      if (alertShown) return;
      if (snap.docs.isEmpty) return;

      for (final doc in snap.docs) {
        final data = doc.data();

        // VALIDATE MATCH
        final bool isMatch =
            (data["caregiverId"] == caregiverId) ||
            (data["deviceId"] == pairedDevice);

        if (!isMatch) continue;

        final delivered = data["delivered"] ?? false;
        if (delivered) continue;

        FirebaseFirestore.instance
            .collection("alerts")
            .doc(doc.id)
            .update({"delivered": true});

        alertShown = true;

        Navigator.pushReplacementNamed(
          context,
          "/alert",
          arguments: {
            "location": data["location"] ?? "Unknown",
            "lat": data["lat"],
            "lng": data["lng"],
            "mapURL": data["mapURL"],
            "alertId": doc.id,
            "fallType": data["fallType"] ?? "Fall Detected",
          },
        );
        break;
      }
    });
  }

  // ============================================================
  // INIT
  // ============================================================
  @override
  void initState() {
    super.initState();

    // Alerts only after onboarding finished
    _listenForAlerts();

    Future.delayed(const Duration(milliseconds: 200), () async {
      final route = await _decideRoute();

      if (!alertShown && mounted) {
        Navigator.pushReplacementNamed(context, route);
      }
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
        child: CircularProgressIndicator(
          color: Color(0xFF33B5FF),
        ),
      ),
    );
  }
}
