import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceFoundScreen extends StatefulWidget {
  const DeviceFoundScreen({super.key});

  @override
  State<DeviceFoundScreen> createState() => _DeviceFoundScreenState();
}

class _DeviceFoundScreenState extends State<DeviceFoundScreen>
    with SingleTickerProviderStateMixin {
  String deviceId = "Loading...";
  bool deviceFound = false;
  bool deviceOnline = false;
  bool _redirected = false;

  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..forward();

    _checkPairedDevice();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  // ======================================================
  // CHECK IF DEVICE IS PAIRED & ONLINE
  // ======================================================
  Future<void> _checkPairedDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final caregiverId = prefs.getString("caregiverId") ?? "";

      if (caregiverId.isEmpty) {
        _showError("No caregiver session found");
        return;
      }

      final firestore = FirebaseFirestore.instance;

      // → Check caregiver profile
      final caregiverDoc =
          await firestore.collection("caregivers").doc(caregiverId).get();

      if (!caregiverDoc.exists) {
        _showError("Caregiver profile missing");
        return;
      }

      final pairedDevice = caregiverDoc.data()!["pairedDevice"];

      if (pairedDevice == null || pairedDevice.trim().isEmpty) {
        _showError("No paired device");
        return;
      }

      setState(() {
        deviceId = pairedDevice;
        deviceFound = true;
      });

      // → Check actual device document
      final deviceDoc =
          await firestore.collection("devices").doc(pairedDevice).get();

      if (!deviceDoc.exists) {
        return _safeRedirect(() {
          Navigator.pushReplacementNamed(context, "/device-pairing");
        });
      }

      final dev = deviceDoc.data()!;
      DateTime? lastSync;

      if (dev["lastSync"] is Timestamp) {
        lastSync = (dev["lastSync"] as Timestamp).toDate();
      } else if (dev["lastSync"] is String) {
        lastSync = DateTime.tryParse(dev["lastSync"]);
      }

      bool online = false;
      if (lastSync != null) {
        online = DateTime.now().difference(lastSync).inSeconds <= 20;
      }

      setState(() => deviceOnline = online);

      // REDIRECT
      if (online) {
        return _safeRedirect(() {
          Navigator.pushReplacementNamed(context, "/dashboard");
        });
      }

      return _safeRedirect(() {
        Navigator.pushReplacementNamed(context, "/connecting-to-senra");
      });
    } catch (e) {
      _showError("Error loading device");
      debugPrint("DeviceFoundScreen Error: $e");
    }
  }

  // ======================================================
  // UI HELPERS
  // ======================================================
  void _safeRedirect(VoidCallback action) {
    if (_redirected || !mounted) return;
    _redirected = true;

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      action();
    });
  }

  void _showError(String message) {
    setState(() {
      deviceFound = false;
      deviceId = message;
    });
  }

  // ======================================================
  // UI
  // ======================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1625),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // HEADER
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white70),
                    ),
                    const Text(
                      "Device Pairing",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  ],
                ),

                const SizedBox(height: 20),

                // TITLE
                Text(
                  deviceFound ? "Device Found" : "Device Not Found",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 8),

                // SUBTEXT
                Text(
                  deviceFound
                      ? (deviceOnline
                          ? "Device is online — Preparing dashboard"
                          : "Setting up connection...")
                      : "No paired device found.",
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),

                const SizedBox(height: 26),

                // DEVICE CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF162233),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B2A3A),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              !deviceFound
                                  ? Icons.error_outline
                                  : (deviceOnline
                                      ? Icons.check_circle
                                      : Icons.watch_outlined),
                              size: 28,
                              color: deviceFound
                                  ? (deviceOnline
                                      ? Colors.greenAccent
                                      : Colors.lightBlueAccent)
                                  : Colors.redAccent,
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Device name & ID
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                deviceId,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                deviceFound
                                    ? "Checking status…"
                                    : "Please try pairing again",
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 12),
                              )
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 25),

                      // Progress bar
                      AnimatedBuilder(
                        animation: _progressController,
                        builder: (_, __) {
                          return LinearProgressIndicator(
                            value: _progressController.value,
                            minHeight: 6,
                            color: const Color(0xFF33B5FF),
                            backgroundColor: Colors.white12,
                            borderRadius: BorderRadius.circular(10),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                Text(
                  deviceFound
                      ? "Connecting…"
                      : "Please return to pairing and try again.",
                  style: TextStyle(
                    color: deviceFound ? Colors.white70 : Colors.redAccent,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
