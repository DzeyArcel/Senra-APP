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
  bool _redirected = false;

  @override
  void initState() {
    super.initState();
    _loadDevice();
  }

  @override
  void dispose() {
    deviceListener?.cancel();
    super.dispose();
  }

  // =============================================================
  // LOAD DEVICE + REAL-TIME WATCHER
  // =============================================================
  Future<void> _loadDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final caregiverId = prefs.getString("caregiverId");

    if (caregiverId == null || caregiverId.isEmpty) return;

    // Read caregiver
    final caregiverDoc = await FirebaseFirestore.instance
        .collection("caregivers")
        .doc(caregiverId)
        .get();

    if (!caregiverDoc.exists) return;

    final pairedDevice = caregiverDoc.data()?["pairedDevice"];

    if (pairedDevice == null || pairedDevice.toString().isEmpty) {
      setState(() => deviceId = null);
      return;
    }

    setState(() => deviceId = pairedDevice);

    // Validate device exists
    final deviceDoc = await FirebaseFirestore.instance
        .collection("devices")
        .doc(pairedDevice)
        .get();

    if (!deviceDoc.exists) {
      // Auto-unpair
      await FirebaseFirestore.instance
          .collection("caregivers")
          .doc(caregiverId)
          .update({"pairedDevice": ""});

      await prefs.remove("pairedDevice");

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, "/device-pairing");
      return;
    }

    // REALTIME FIRESTORE WATCHER
    deviceListener = FirebaseFirestore.instance
        .collection("devices")
        .doc(pairedDevice)
        .snapshots()
        .listen((snap) {
      if (!snap.exists) return;

      final data = snap.data()!;
      deviceData = data;

      // -------- STATUS --------
      bool online = false;

      // Read lastSync → Timestamp or String
      DateTime? lastSync;
      final rawSync = data["lastSync"];

      if (rawSync is Timestamp) lastSync = rawSync.toDate();
      if (rawSync is String) lastSync = DateTime.tryParse(rawSync);

      // 20-second rule
      if (lastSync != null) {
        final diff = DateTime.now().difference(lastSync).inSeconds;
        online = diff <= 20;
      }

      if (mounted) setState(() => isOnline = online);

      // -------- AUTO REDIRECT --------
      if (online && !_redirected) {
        _redirected = true;
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, "/dashboard");
        });
      }
    });
  }

  // =============================================================
  // TIMESTAMP FORMATTER
  // =============================================================
  String _formatTimeAgo(dynamic raw) {
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

  // =============================================================
  // UI
  // =============================================================
  @override
  Widget build(BuildContext context) {
    if (deviceId == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0E1625),
        body: const Center(
          child: Text(
            "No paired Senra device found.",
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    final battery = deviceData?["batteryLevel"] ??
        deviceData?["battery"] ??
        0;

    final lastSyncText = _formatTimeAgo(deviceData?["lastSync"]);

    return Scaffold(
      backgroundColor: const Color(0xFF0E1625),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // HEADER -----------------------------------------------------
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white70),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    "Device Status",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // ONLINE STATUS ICON ------------------------------------------
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isOnline
                        ? const Color(0xFF33B5FF)
                        : Colors.redAccent,
                    width: 4,
                  ),
                ),
                child: Center(
                  child: Icon(
                    isOnline ? Icons.check_circle : Icons.error_outline,
                    size: 65,
                    color:
                        isOnline ? const Color(0xFF33B5FF) : Colors.redAccent,
                  ),
                ),
              ),

              const SizedBox(height: 22),

              Text(
                isOnline ? "Device is Online!" : "Waiting for Device...",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                isOnline
                    ? "Senra is now sending data successfully."
                    : "Please power on the device or complete Wi-Fi setup.",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 30),

              // ICON FLOW ---------------------------------------------------
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.watch, color: Color(0xFF33B5FF), size: 40),
                  SizedBox(width: 20),
                  Icon(Icons.arrow_forward, color: Colors.white38, size: 25),
                  SizedBox(width: 20),
                  Icon(Icons.smartphone, color: Color(0xFF33B5FF), size: 40),
                ],
              ),

              const SizedBox(height: 30),

              // DEVICE CARD -------------------------------------------------
              Container(
                padding: const EdgeInsets.all(18),
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
                        color:
                            isOnline ? Colors.lightGreenAccent : Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Last Sync: $lastSyncText\nBattery: $battery%",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 35),

              // CONTINUE SETUP BUTTON ---------------------------------------
              if (!isOnline)
                GestureDetector(
                  onTap: () =>
                      Navigator.pushNamed(context, "/connecting-to-senra"),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF33B5FF),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Center(
                      child: Text(
                        "Continue Setup",
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
