import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConnectingToSenraScreen extends StatefulWidget {
  const ConnectingToSenraScreen({super.key});

  @override
  State<ConnectingToSenraScreen> createState() =>
      _ConnectingToSenraScreenState();
}

class _ConnectingToSenraScreenState extends State<ConnectingToSenraScreen> {
  String? deviceId;
  StreamSubscription? sub;
  bool redirected = false;

  @override
  void initState() {
    super.initState();
    _startMonitoring();
  }

  @override
  void dispose() {
    sub?.cancel();
    super.dispose();
  }

  // ============================================================
  // START WATCHING DEVICE STATUS — FINAL LOGIC
  // ============================================================
  Future<void> _startMonitoring() async {
    final prefs = await SharedPreferences.getInstance();
    deviceId = prefs.getString("pairedDevice");

    if (deviceId == null || deviceId!.isEmpty) return;

    final ref =
        FirebaseFirestore.instance.collection("devices").doc(deviceId);

    sub = ref.snapshots().listen((snap) {
      if (!snap.exists || redirected) return;

      final data = snap.data() ?? {};

      // ---------------- WIFI NAME (SAFE READ) ----------------
      final wifi = data["wifiName"] ??
          data["wifi"] ??
          "";

      // ---------------- LAST SYNC (SAFE READ) ----------------
      DateTime? lastSync;
      final rawSync = data["lastSync"];

      if (rawSync is Timestamp) lastSync = rawSync.toDate();
      if (rawSync is String) lastSync = DateTime.tryParse(rawSync);

      bool online = false;

      if (lastSync != null) {
        final diff = DateTime.now().difference(lastSync).inSeconds;
        online = diff <= 20; // ecosystem rule
      }

      // ============================================================
      // FINAL LOGIC:
      // 1️⃣ If device has WiFi → Dashboard
      // 2️⃣ If device is online WITHOUT WiFi → WiFi Config
      // 3️⃣ Otherwise keep waiting
      // ============================================================

      if (wifi.toString().isNotEmpty) {
        _go("/dashboard");
      } else if (online) {
        _go("/wifi-config");
      }
    });

    // ============================================================
    // SAFETY TIMEOUT: 6 SEC
    // If no response → WiFi Config screen
    // ============================================================
    Future.delayed(const Duration(seconds: 6), () {
      if (!mounted || redirected) return;
      _go("/wifi-config");
    });
  }

  // ============================================================
  // SAFE NAVIGATOR
  // ============================================================
  void _go(String route) {
    if (!mounted || redirected) return;

    redirected = true;
    Navigator.pushReplacementNamed(context, route);
  }

  // ============================================================
  // UI — EXACTLY AS YOU DESIGNED
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1625),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                color: Color(0xFF33B5FF),
                strokeWidth: 4,
              ),
            ),
            SizedBox(height: 30),
            Text(
              "Connecting to Senra…",
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Waiting for your device to power on.",
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
