// ============================================================
// WifiConfigScreen.dart — FINAL FIX (LASTSYNC SOURCE OF TRUTH)
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class WifiConfigScreen extends StatefulWidget {
  const WifiConfigScreen({super.key});

  @override
  State<WifiConfigScreen> createState() => _WifiConfigScreenState();
}

class _WifiConfigScreenState extends State<WifiConfigScreen> {
  String statusText = "Preparing Senra Wi-Fi setup. Please wait…";

  String? deviceId;
  StreamSubscription? sub;
  bool listening = false;

  @override
  void initState() {
    super.initState();
    _startFlow();
  }

  @override
  void dispose() {
    sub?.cancel();
    super.dispose();
  }

  // ============================================================
  // BACK
  // ============================================================
  Future<void> _handleBack() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("needsWifiSetup", true);
    await sub?.cancel();

    if (!mounted) return;
    Navigator.pop(context);
  }

  // ============================================================
  // MAIN FLOW
  // ============================================================
  Future<void> _startFlow() async {
    final prefs = await SharedPreferences.getInstance();
    deviceId = prefs.getString("pairedDevice");

    if (deviceId == null || deviceId!.isEmpty) {
      setState(() => statusText = "No paired device found.");
      return;
    }

    final ref =
        FirebaseFirestore.instance.collection("devices").doc(deviceId);

    // 🔍 CHECK IF DEVICE IS ALREADY ONLINE (LASTSYNC ONLY)
    final snap = await ref.get();
    final data = snap.data() ?? {};
    final lastSync = data["lastSync"];

    DateTime? t;
    if (lastSync is Timestamp) t = lastSync.toDate();
    if (lastSync is String) t = DateTime.tryParse(lastSync);

    final online =
        t != null && DateTime.now().difference(t).inSeconds <= 20;

    if (online) {
      await prefs.setBool("needsWifiSetup", false);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, "/dashboard");
      return;
    }

    // 🔁 REQUEST WIFI RESET
    await ref.update({"adminCommand": "reset_wifi"});

    setState(() {
      statusText =
          "Senra is in setup mode.\n\n"
          "1. Connect to SENRA-Setup Wi-Fi\n"
          "2. Enter your Wi-Fi credentials\n"
          "3. Return here and wait";
    });

    _listenForReconnect();
  }

  // ============================================================
  // LISTEN FOR DEVICE COMING ONLINE
  // ============================================================
  void _listenForReconnect() {
    if (deviceId == null || listening) return;
    listening = true;

    final ref =
        FirebaseFirestore.instance.collection("devices").doc(deviceId);

    sub = ref.snapshots().listen((snap) async {
      if (!snap.exists) return;

      final data = snap.data() ?? {};
      final lastSync = data["lastSync"];

      DateTime? t;
      if (lastSync is Timestamp) t = lastSync.toDate();
      if (lastSync is String) t = DateTime.tryParse(lastSync);

      final online =
          t != null && DateTime.now().difference(t).inSeconds <= 20;

      if (!online) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool("needsWifiSetup", false);
      await ref.update({"adminCommand": ""});

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, "/dashboard");
    });
  }

  // ============================================================
  // OPEN WIFI SETTINGS
  // ============================================================
  Future<void> _openWifiSettings() async {
    await launchUrl(Uri.parse("App-Prefs:root=WIFI"));
  }

  // ============================================================
  // OPEN ESP32 PAGE
  // ============================================================
  Future<void> _openSetupPage() async {
    const url = "http://192.168.4.1";

    setState(() => statusText = "Opening Senra setup page…");

    try {
      await launchUrl(Uri.parse(url),
          mode: LaunchMode.inAppBrowserView);

      setState(() =>
          statusText = "Waiting for Senra to reconnect…");
    } catch (_) {
      setState(() => statusText =
          "Failed to open setup page.\nConnect to SENRA-Setup Wi-Fi.");
    }
  }

  // ============================================================
  // UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1625),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: _handleBack,
                icon: const Icon(Icons.arrow_back, color: Colors.white70),
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF162233),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.wifi, color: Color(0xFF33B5FF)),
                        SizedBox(width: 8),
                        Text(
                          "Connect Senra to Wi-Fi",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      statusText,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: _openWifiSettings,
                      style: _btn,
                      child: const Text("1. Open Wi-Fi Settings"),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _openSetupPage,
                      style: _btn,
                      child: const Text("2. Continue to Setup Page"),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ButtonStyle get _btn => ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF33B5FF),
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );
}
