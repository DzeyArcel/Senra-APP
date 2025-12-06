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
  String statusText =
      "Requesting Senra to enter Wi-Fi setup mode…\nPlease wait.";
  bool waitingForReconnect = false;

  String? deviceId;
  StreamSubscription? sub;

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
  // MAIN SEQUENCE
  // ============================================================
  Future<void> _startFlow() async {
    final prefs = await SharedPreferences.getInstance();
    deviceId = prefs.getString("pairedDevice");

    if (deviceId == null) {
      setState(() => statusText = "No device paired.");
      return;
    }

    // 1️⃣ Tell firmware to enter setup mode
    await FirebaseFirestore.instance
        .collection("devices")
        .doc(deviceId)
        .update({"adminCommand": "reset_wifi"});

    setState(() {
      statusText =
          "Senra is switching to Wi-Fi setup mode…\nThis may take a few seconds.";
    });

    // Begin listening for reconnect
    _startReconnectListener();
  }

  // ============================================================
  // LISTEN FOR DEVICE COMING BACK ONLINE
  // ============================================================
  void _startReconnectListener() {
    if (deviceId == null) return;

    final ref = FirebaseFirestore.instance.collection("devices").doc(deviceId);

    sub = ref.snapshots().listen((snap) {
      if (!waitingForReconnect) return;

      if (!snap.exists) return;

      final data = snap.data() ?? {};
      final wifi = data["wifiName"] ?? "";
      final status = data["status"] ?? "";
      final lastSync = data["lastSync"];

      if (wifi.toString().isNotEmpty && status == "online") {
        Navigator.pushReplacementNamed(context, "/all-set");
      }
    });
  }

  // ============================================================
  // OPEN WiFi SETTINGS
  // ============================================================
  Future<void> _openWifiSettings() async {
    await launchUrl(Uri.parse("App-Prefs:root=WIFI"));
  }

  // ============================================================
  // OPEN SETUP PAGE AFTER USER CONNECTED
  // ============================================================
  Future<void> _openSetupPage() async {
    const url = "http://192.168.4.1";

    setState(() {
      statusText = "Opening Senra setup page…\nEnter Wi-Fi credentials.";
    });

    await Future.delayed(const Duration(milliseconds: 300));

    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);

      setState(() {
        waitingForReconnect = true;
        statusText =
            "When finished, Senra will reconnect.\nPlease wait…";
      });
    } catch (e) {
      setState(() {
        statusText =
            "Failed to open setup page.\nPlease ensure you're connected to SENRA-Setup Wi-Fi.";
      });
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
                onPressed: () => Navigator.pop(context),
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
                    Row(
                      children: const [
                        Icon(Icons.wifi, color: Color(0xFF33B5FF)),
                        SizedBox(width: 8),
                        Text(
                          "Change Wi-Fi Network",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700),
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

                    // ==============================
                    // STEP BUTTONS
                    // ==============================
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

                    const SizedBox(height: 20),

                    const Text(
                      "Make sure to connect to:\nWi-Fi: SENRA-Setup",
                      style: TextStyle(color: Colors.white38, fontSize: 12),
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
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );
}
