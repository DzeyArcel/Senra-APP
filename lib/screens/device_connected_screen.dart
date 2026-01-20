// ============================================================
// DeviceConnectedScreen.dart — FINAL STABLE (NO LOOP)
// ✔ Clears needsWifiSetup
// ✔ Finishes setup correctly
// ✔ Routes to Dashboard
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceConnectedScreen extends StatefulWidget {
  const DeviceConnectedScreen({super.key});

  @override
  State<DeviceConnectedScreen> createState() => _DeviceConnectedScreenState();
}

class _DeviceConnectedScreenState extends State<DeviceConnectedScreen> {
  String? deviceId;
  Map<String, dynamic>? deviceData;
  bool isOnline = false;

  StreamSubscription? deviceListener;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    deviceListener?.cancel();
    super.dispose();
  }

  // ============================================================
  // INITIAL LOAD
  // ============================================================
  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final paired = prefs.getString("pairedDevice");

    if (paired == null || paired.isEmpty) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, "/device-pairing");
      return;
    }

    setState(() => deviceId = paired);

    final snap = await FirebaseFirestore.instance
        .collection("devices")
        .doc(paired)
        .get();

    if (!snap.exists) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, "/device-pairing");
      return;
    }

    deviceData = snap.data();

    deviceListener = FirebaseFirestore.instance
        .collection("devices")
        .doc(paired)
        .snapshots()
        .listen(_handleDeviceUpdate);
  }

  // ============================================================
  // DEVICE STATUS LISTENER
  // ============================================================
  void _handleDeviceUpdate(DocumentSnapshot snap) {
    if (!snap.exists) return;

    final data = snap.data()! as Map<String, dynamic>;
    deviceData = data;

    DateTime? last;
    final raw = data["lastSync"];

    if (raw is Timestamp) last = raw.toDate();
    if (raw is String) last = DateTime.tryParse(raw);

    bool online = false;
    if (last != null) {
      online = DateTime.now().difference(last).inSeconds < 25;
    }

    if (mounted) {
      setState(() => isOnline = online);
    }
  }

  // ============================================================
  // 🔥 FINISH SETUP — THIS FIXES THE LOOP
  // ============================================================
  Future<void> _finishSetup() async {
    final prefs = await SharedPreferences.getInstance();

    // 🔥 CRITICAL FIX
    await prefs.setBool("needsWifiSetup", false);

    if (deviceId != null) {
      await FirebaseFirestore.instance
          .collection("devices")
          .doc(deviceId)
          .update({
        "setupComplete": true,
        "status": "online",
      });
    }

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      "/dashboard",
      (_) => false,
    );
  }

  // ============================================================
  // UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    if (deviceId == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0E1625),
        body: Center(
          child: Text(
            "No paired device found.",
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    final battery = deviceData?["batteryLevel"] ?? 0;
    final lastSync = _timeAgo(deviceData?["lastSync"]);

    return Scaffold(
      backgroundColor: const Color(0xFF0E1625),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white70),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    "Device Connected",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              const Icon(
                Icons.check_circle_rounded,
                size: 110,
                color: Colors.lightBlueAccent,
              ),

              const SizedBox(height: 20),

              const Text(
                "Connected Successfully!",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                "Your Senra wearable is now connected\nand monitoring.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),

              const SizedBox(height: 30),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF162233),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(
                      deviceId!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isOnline ? "Online" : "Offline",
                      style: TextStyle(
                        color: isOnline
                            ? Colors.lightGreenAccent
                            : Colors.redAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Last Sync: $lastSync\nBattery: $battery%",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 35),

              // ✅ FINAL BUTTON
              GestureDetector(
                onTap: _finishSetup,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF33B5FF),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Center(
                    child: Text(
                      "Finish Setup",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  String _timeAgo(dynamic raw) {
    DateTime? dt;
    if (raw is Timestamp) dt = raw.toDate();
    if (raw is String) dt = DateTime.tryParse(raw);
    if (dt == null) return "Unknown";

    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes} min ago";
    if (diff.inHours < 24) return "${diff.inHours} hrs ago";
    return "${diff.inDays} days ago";
  }
}
