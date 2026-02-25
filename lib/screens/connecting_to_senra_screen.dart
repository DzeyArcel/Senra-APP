// ============================================================
// ConnectingToSenraScreen — FINAL ECOSYSTEM-SAFE VERSION
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ConnectingToSenraScreen extends StatefulWidget {
  const ConnectingToSenraScreen({super.key});

  @override
  State<ConnectingToSenraScreen> createState() =>
      _ConnectingToSenraScreenState();
}

class _ConnectingToSenraScreenState extends State<ConnectingToSenraScreen> {
  StreamSubscription? deviceSub;
  bool redirected = false;

  @override
  void initState() {
    super.initState();
    _listenForDeviceOnline();
  }

  // ============================================================
  // 🔍 WAIT FOR DEVICE TO COME ONLINE
  // ============================================================
  Future<void> _listenForDeviceOnline() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString("pairedDevice") ?? "";

    if (deviceId.isEmpty) {
      _go("/device-pairing");
      return;
    }

    deviceSub = FirebaseFirestore.instance
        .collection("devices")
        .doc(deviceId)
        .snapshots()
        .listen((snap) async {
      if (!snap.exists) return;

      final data = snap.data()!;
      final lastSync = data["lastSync"];

      DateTime? t;
      if (lastSync is Timestamp) t = lastSync.toDate();
      if (lastSync is String) t = DateTime.tryParse(lastSync);

      if (t == null) return;

      final online =
          DateTime.now().difference(t).inSeconds <= 20;

      if (!online) return;


      // ✅ LET STARTUP ROUTER DECIDE FINAL SCREEN
      _go("/startup");
    });
  }

  void _go(String route) {
    if (!mounted || redirected) return;
    redirected = true;
    deviceSub?.cancel();
    Navigator.pushReplacementNamed(context, route);
  }

  @override
  void dispose() {
    deviceSub?.cancel();
    super.dispose();
  }

  // ============================================================
  // UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1625),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                color: Color(0xFF33B5FF),
                strokeWidth: 4,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Connecting to Senra…",
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Waiting for device to come online",
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 28),

            // Manual fallback
            TextButton(
              onPressed: () => _go("/wifi-config"),
              child: const Text(
                "Set up Wi-Fi again",
                style: TextStyle(
                  color: Color(0xFF33B5FF),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
