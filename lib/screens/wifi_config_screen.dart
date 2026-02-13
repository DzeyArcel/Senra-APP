// ============================================================
// WifiConfigScreen.dart — THEMED + UX FINAL
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

enum WifiStep {
  instructions,
  waitingForReconnect,
  connected,
}

class WifiConfigScreen extends StatefulWidget {
  const WifiConfigScreen({super.key});

  @override
  State<WifiConfigScreen> createState() => _WifiConfigScreenState();
}

class _WifiConfigScreenState extends State<WifiConfigScreen> {
  String? deviceId;
  StreamSubscription? sub;

  WifiStep step = WifiStep.instructions;
  bool completed = false;
  bool setupPageOpened = false;

  DateTime? onlineSince;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startFlow());
  }

  @override
  void dispose() {
    sub?.cancel();
    super.dispose();
  }

  // ============================================================
  Future<void> _startFlow() async {
    final prefs = await SharedPreferences.getInstance();
    deviceId = prefs.getString("pairedDevice");
    if (deviceId == null || deviceId!.isEmpty) return;
    _listenForStableOnline();
  }

  // ============================================================
  void _listenForStableOnline() {
  final ref =
      FirebaseFirestore.instance.collection("devices").doc(deviceId!);

  sub = ref.snapshots().listen((snap) async {
    if (!snap.exists || completed) return;

    final lastSync = snap.data()!["lastSync"];
    DateTime? t;
    if (lastSync is Timestamp) t = lastSync.toDate();
    if (lastSync is String) t = DateTime.tryParse(lastSync);

    final online =
        t != null && DateTime.now().difference(t).inSeconds <= 15;

    // 🔴 Device offline → reset timer
    if (!online) {
      onlineSince = null;
      return;
    }

    // 🟡 Online but not stable yet
    onlineSince ??= DateTime.now();
    if (DateTime.now().difference(onlineSince!).inSeconds < 10) {
      if (step != WifiStep.waitingForReconnect) {
        setState(() => step = WifiStep.waitingForReconnect);
      }
      return;
    }

    // 🟢 STABLE ONLINE — COMPLETE FLOW
    completed = true;

    final prefs = await SharedPreferences.getInstance();

    // 🔓 CRITICAL: FULLY UNLOCK WIFI FLOW
    await prefs.setBool("needsWifiSetup", false);
    await prefs.setBool("wifiLock", false);
    await prefs.setBool("wifiResetSent", false);
    await prefs.remove("wifiResetAt");

    debugPrint("✅ Wi-Fi setup fully completed — all locks cleared");

    await sub?.cancel();

    if (!mounted) return;
    setState(() => step = WifiStep.connected);

    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    Navigator.pushReplacementNamed(context, "/dashboard");
  });
}


  // ============================================================
  Future<void> _openWifiSettings() async {
    await launchUrl(Uri.parse("App-Prefs:root=WIFI"));
  }

  Future<void> _openSetupPage() async {
    setState(() => setupPageOpened = true);
    await launchUrl(
      Uri.parse("http://192.168.4.1"),
      mode: LaunchMode.inAppBrowserView,
    );
  }

  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1625),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              // 🧭 STEP HEADER
              _StepHeader(step: step),

              const SizedBox(height: 24),

              // 🧱 MAIN CARD
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xFF162233),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusBanner(step: step),

                    const SizedBox(height: 20),

                    _InstructionText(step: step),

                    const SizedBox(height: 28),

                    ElevatedButton(
                      onPressed: _openWifiSettings,
                      style: _btnPrimary,
                      child: const Text("Open Wi-Fi Settings"),
                    ),

                    const SizedBox(height: 14),

                    ElevatedButton(
                      onPressed: _openSetupPage,
                      style: _btnSecondary,
                      child: Text(
                        setupPageOpened
                            ? "Reopen Setup Page"
                            : "Open Setup Page",
                      ),
                    ),

                    if (step == WifiStep.waitingForReconnect) ...[
                      const SizedBox(height: 28),
                      const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF33B5FF),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  ButtonStyle get _btnPrimary => ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF33B5FF),
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      );

  ButtonStyle get _btnSecondary => ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF22314D),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      );
}

// ============================================================
// COMPONENTS
// ============================================================

class _StepHeader extends StatelessWidget {
  final WifiStep step;
  const _StepHeader({required this.step});

  @override
  Widget build(BuildContext context) {
    final index = step.index + 1;
    return Text(
      "Step $index of 3",
      style: const TextStyle(
        color: Color(0xFF33B5FF),
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final WifiStep step;
  const _StatusBanner({required this.step});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    String text;

    switch (step) {
      case WifiStep.instructions:
        icon = Icons.wifi;
        text = "Connect to SENRA-SETUP";
        break;
      case WifiStep.waitingForReconnect:
        icon = Icons.sync;
        text = "Connecting to your Wi-Fi…";
        break;
      case WifiStep.connected:
        icon = Icons.check_circle;
        text = "Connected";
        break;
    }

    return Row(
      children: [
        Icon(icon, color: const Color(0xFF33B5FF)),
        const SizedBox(width: 10),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _InstructionText extends StatelessWidget {
  final WifiStep step;
  const _InstructionText({required this.step});

  @override
  Widget build(BuildContext context) {
    String text;

    switch (step) {
      case WifiStep.instructions:
        text =
            "1. Open Wi-Fi settings\n"
            "2. Connect to **SENRA-SETUP**\n"
            "3. Open the setup page\n"
            "4. Enter home Wi-Fi\n"
            "5. Return here";
        break;
      case WifiStep.waitingForReconnect:
        text =
            "Senra is restarting and connecting.\n\n"
            "This usually takes under a minute.\n"
            "You can reopen the setup page if needed.";
        break;
      case WifiStep.connected:
        text = "Wi-Fi connected successfully.";
        break;
    }

    return Text(
      text,
      style: const TextStyle(
        color: Colors.white70,
        height: 1.6,
      ),
    );
  }
}
