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
  String _status = "Requesting Senra to enter Wi-Fi setup mode...";
  bool setupPageOpened = false;
  bool redirected = false;
  String? deviceId;
  StreamSubscription? sub;

  @override
  void initState() {
    super.initState();
    _startProcess();
  }

  @override
  void dispose() {
    sub?.cancel();
    super.dispose();
  }

  // =====================================================================
  // START WiFi Setup Process (includes realtime monitoring)
  // =====================================================================
  Future<void> _startProcess() async {
    await _loadDeviceId();
    if (deviceId == null) {
      setState(() => _status = "No paired device detected.");
      return;
    }

    // 1️⃣ Command ESP32 to enter WiFi reset mode
    await FirebaseFirestore.instance
        .collection("devices")
        .doc(deviceId)
        .update({"adminCommand": "reset_wifi"});

    setState(() => _status = "Senra is now entering Wi-Fi setup mode...");

    // small delay before opening browser
    await Future.delayed(const Duration(seconds: 3));
    _openSetupPage();

    // 2️⃣ Start realtime monitoring
    _watchDeviceWifiStatus();

    // 3️⃣ Safe timeout to detect AP mode
    Future.delayed(const Duration(seconds: 10), () {
      if (!mounted || redirected) return;

      setState(() {
        _status =
            "Could not detect Senra AP.\nPlease connect manually to 'SENRA-Setup' Wi-Fi.";
      });
    });
  }

  // =====================================================================
  // Load paired device from local storage
  // =====================================================================
  Future<void> _loadDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    deviceId = prefs.getString("pairedDevice");
  }

  // =====================================================================
  // Open 192.168.4.1 setup page
  // =====================================================================
  Future<void> _openSetupPage() async {
    const url = "http://192.168.4.1/";
    final uri = Uri.parse(url);

    try {
      await launchUrl(uri, mode: LaunchMode.inAppBrowserView);

      setState(() {
        setupPageOpened = true;
        _status = "Senra setup page opened successfully.";
      });
    } catch (e) {
      setState(() {
        _status =
            "Failed to open setup page.\nConnect to 'SENRA-Setup' Wi-Fi manually.";
      });
    }
  }

  // =====================================================================
  // Watch Firestore for WiFi name (means setup complete)
  // =====================================================================
  void _watchDeviceWifiStatus() {
    if (deviceId == null) return;

    final ref =
        FirebaseFirestore.instance.collection("devices").doc(deviceId);

    sub = ref.snapshots().listen((snap) {
      if (!snap.exists || redirected) return;

      final data = snap.data() ?? {};
      final wifi = data["wifiName"] ??
          data["wifi"] ??
          "";

      // WiFi finally configured → go All Set
      if (wifi.toString().isNotEmpty) {
        _next("/all-set");
      }
    });
  }

  // =====================================================================
  // Redirect handler (prevents double navigation)
  // =====================================================================
  void _next(String route) {
    if (redirected || !mounted) return;
    redirected = true;
    Navigator.pushReplacementNamed(context, route);
  }

  // =====================================================================
  // UI (unchanged)
  // =====================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1625),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white70),
                ),

                const SizedBox(height: 10),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF162233),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.wifi, color: Color(0xFF33B5FF)),
                          SizedBox(width: 8),
                          Text(
                            "Connect Senra to Wi-Fi",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      Text(
                        _status,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),

                      const SizedBox(height: 22),

                      Container(
                        height: 240,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B2A3A),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.router_rounded,
                            color: Colors.white38,
                            size: 60,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      const Text(
                        "1. Senra will switch to Access Point mode.\n"
                        "2. Your phone should detect 'SENRA-Setup' Wi-Fi.\n"
                        "3. The setup page opens automatically.\n"
                        "4. Enter your home Wi-Fi name & password.",
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 14),

                      const Center(
                        child: Text(
                          "Senra Setup Address:\nhttp://192.168.4.1",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
