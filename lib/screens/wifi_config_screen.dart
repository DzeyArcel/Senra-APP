// ============================================================
// WifiConfigScreen.dart — UX POLISHED (LOGIC UNCHANGED)
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

  Future<void> _startFlow() async {
    final prefs = await SharedPreferences.getInstance();
    deviceId = prefs.getString("pairedDevice");
    if (deviceId == null || deviceId!.isEmpty) return;
    _listenForStableOnline();
  }

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

      if (!online) {
        onlineSince = null;
        return;
      }

      onlineSince ??= DateTime.now();

      if (DateTime.now().difference(onlineSince!).inSeconds < 10) {
        if (step != WifiStep.waitingForReconnect) {
          setState(() => step = WifiStep.waitingForReconnect);
        }
        return;
      }

      completed = true;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool("needsWifiSetup", false);
      await prefs.setBool("wifiLock", false);
      await prefs.setBool("wifiResetSent", false);
      await prefs.remove("wifiResetAt");

      await sub?.cancel();

      if (!mounted) return;
      setState(() => step = WifiStep.connected);

      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;

      Navigator.pushReplacementNamed(context, "/dashboard");
    });
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1625),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              const Text(
                "Connect Your Device",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Let’s get your Senra device online",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),

              const SizedBox(height: 22),

              _StepIndicator(step: step),

              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xFF162233),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusHeader(step: step),
                    const SizedBox(height: 16),
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
                            : "Open Device Setup Page",
                      ),
                    ),

                    if (step == WifiStep.waitingForReconnect) ...[
                      const SizedBox(height: 28),
                      const _ConnectingIndicator(),
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

  ButtonStyle get _btnPrimary => ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF33B5FF),
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      );

  ButtonStyle get _btnSecondary => ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF22314D),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      );
}

// ============================================================
// UI COMPONENTS
// ============================================================

class _StepIndicator extends StatelessWidget {
  final WifiStep step;
  const _StepIndicator({required this.step});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (i) {
        final active = i <= step.index;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 4,
            margin: EdgeInsets.only(right: i == 2 ? 0 : 6),
            decoration: BoxDecoration(
              color:
                  active ? const Color(0xFF33B5FF) : Colors.white12,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  final WifiStep step;
  const _StatusHeader({required this.step});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    String title;

    switch (step) {
      case WifiStep.instructions:
        icon = Icons.wifi;
        title = "Connect to Senra Setup Wi-Fi";
        break;
      case WifiStep.waitingForReconnect:
        icon = Icons.sync;
        title = "Connecting Securely";
        break;
      case WifiStep.connected:
        icon = Icons.check_circle;
        title = "Connected Successfully";
        break;
    }

    return Row(
      children: [
        Icon(icon, color: const Color(0xFF33B5FF), size: 22),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
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
            "1. Open Wi-Fi settings and connect to **SENRA-SETUP**\n"
            "2. Open the device setup page\n"
            "3. Enter your home Wi-Fi details\n"
            "4. Return here and wait for confirmation";
        break;
      case WifiStep.waitingForReconnect:
        text =
            "Your device is restarting and connecting to your home Wi-Fi.\n\n"
            "This usually takes less than a minute.";
        break;
      case WifiStep.connected:
        text =
            "Your Senra device is now online and ready.\n\n"
            "You’ll be redirected automatically.";
        break;
    }

    return Text(
      text,
      style: const TextStyle(
        color: Colors.white70,
        height: 1.6,
        fontSize: 14,
      ),
    );
  }
}

class _ConnectingIndicator extends StatelessWidget {
  const _ConnectingIndicator();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        SizedBox(height: 8),
        CircularProgressIndicator(
          color: Color(0xFF33B5FF),
          strokeWidth: 3,
        ),
        SizedBox(height: 12),
        Text(
          "Waiting for device to come online…",
          style: TextStyle(color: Colors.white70),
        ),
      ],
    );
  }
}