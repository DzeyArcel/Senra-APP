import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceFoundScreen extends StatefulWidget {
  const DeviceFoundScreen({super.key});

  @override
  State<DeviceFoundScreen> createState() => _DeviceFoundScreenState();
}

class _DeviceFoundScreenState extends State<DeviceFoundScreen>
    with SingleTickerProviderStateMixin {
  String deviceId = "SENRA DEVICE";
  bool _redirected = false;

  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..forward();

    _loadDeviceAndContinue();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  // ======================================================
  // LOAD DEVICE ID (LOCAL ONLY) + CONTINUE FLOW
  // ======================================================
  Future<void> _loadDeviceAndContinue() async {
    final prefs = await SharedPreferences.getInstance();
    final paired = prefs.getString("pairedDevice");

    if (paired != null && paired.isNotEmpty) {
      setState(() => deviceId = paired);
    }

    // 🔥 DeviceFound NEVER decides routing
    // It always moves forward
    _safeRedirect(() {
      Navigator.pushReplacementNamed(context, "/connecting-senra");
    });
  }

  // ======================================================
  // SAFE REDIRECT
  // ======================================================
  void _safeRedirect(VoidCallback action) {
    if (_redirected || !mounted) return;
    _redirected = true;

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      action();
    });
  }

  // ======================================================
  // UI
  // ======================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071627),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              const SizedBox(height: 30),

              const Text(
                "Device Found",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                "Preparing $deviceId",
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 40),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C2037),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  "Setting up your Senra wearable…",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
              ),

              const SizedBox(height: 40),

              AnimatedBuilder(
                animation: _progressController,
                builder: (_, __) {
                  return LinearProgressIndicator(
                    value: _progressController.value,
                    minHeight: 6,
                    color: const Color(0xFF33B5FF),
                    backgroundColor: Colors.white10,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
