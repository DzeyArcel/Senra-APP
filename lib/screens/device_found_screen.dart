import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceFoundScreen extends StatefulWidget {
  const DeviceFoundScreen({super.key});

  @override
  State<DeviceFoundScreen> createState() => _DeviceFoundScreenState();
}

class _DeviceFoundScreenState extends State<DeviceFoundScreen> {
  String deviceId = "Loading...";
  bool deviceFound = false;
  bool deviceOnline = false;
  bool _redirected = false; // protect from double-navigation

  @override
  void initState() {
    super.initState();
    _checkPairedDevice();
  }

  // ======================================================
  // CHECK IF CAREGIVER HAS A PAIRED DEVICE (FINAL VERSION)
  // ======================================================
  Future<void> _checkPairedDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final caregiverId = prefs.getString("caregiverId") ?? "";

      if (caregiverId.isEmpty) {
        setState(() {
          deviceId = "No caregiver session";
          deviceFound = false;
        });
        return;
      }

      final firestore = FirebaseFirestore.instance;

      // Read caregiver profile
      final caregiverDoc =
          await firestore.collection("caregivers").doc(caregiverId).get();

      if (!caregiverDoc.exists) {
        setState(() {
          deviceId = "No caregiver data";
          deviceFound = false;
        });
        return;
      }

      final data = caregiverDoc.data()!;
      final pairedDevice = data["pairedDevice"];

      if (pairedDevice == null || pairedDevice.toString().trim().isEmpty) {
        setState(() {
          deviceId = "No Device Found";
          deviceFound = false;
        });
        return;
      }

      // Device exists in caregiver document
      setState(() {
        deviceId = pairedDevice;
        deviceFound = true;
      });

      // Check device document
      final deviceDoc =
          await firestore.collection("devices").doc(pairedDevice).get();

      if (!deviceDoc.exists) {
        // Device invalid
        setState(() {
          deviceOnline = false;
        });

        return _safeRedirect(() {
          Navigator.pushReplacementNamed(context, "/device-pairing");
        });
      }

      // SAFE status reading
      final dev = deviceDoc.data()!;
      String status = "offline";

      if (dev["status"] is String) {
        status = dev["status"];
      } else if (dev["status"] is Map) {
        status = dev["status"]["stringValue"] ?? "offline";
      }

      setState(() {
        deviceOnline = status.toLowerCase() == "online";
      });

      // ======================================================
      // REDIRECT RULES
      // ======================================================
      if (deviceOnline) {
        return _safeRedirect(() {
          Navigator.pushReplacementNamed(context, "/dashboard");
        });
      }

      // Device offline → Go to connecting page
      return _safeRedirect(() {
        Navigator.pushReplacementNamed(context, "/connecting-senra");
      });

    } catch (e) {
      debugPrint("DeviceFoundScreen Error: $e");

      setState(() {
        deviceFound = false;
        deviceId = "Error Loading Device";
      });
    }
  }

  // Protect from double navigation
  void _safeRedirect(VoidCallback action) {
    if (_redirected || !mounted) return;
    _redirected = true;

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      action();
    });
  }

  // ======================================================
  // UI (UNCHANGED — CLEANED ONLY)
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
                    const SizedBox(width: 4),
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

                const SizedBox(height: 6),

                // SUBTITLE
                Text(
                  deviceFound
                      ? (deviceOnline
                          ? "Device active — Preparing dashboard"
                          : "Ready to connect to $deviceId")
                      : "We could not find any paired device.",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 25),

                // DEVICE CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF162233),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon + Device ID Row
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
                                      : Icons.bluetooth_searching),
                              color: deviceFound
                                  ? (deviceOnline
                                      ? Colors.greenAccent
                                      : const Color(0xFF33B5FF))
                                  : Colors.redAccent,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 15),

                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                deviceId,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                deviceFound
                                    ? "Device ID: $deviceId"
                                    : "Please try pairing again",
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      if (deviceFound) ...[
                        const SizedBox(height: 20),
                        Container(height: 1, color: Colors.white12),
                        const SizedBox(height: 20),

                        // Battery + Status
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("🔋 Battery Level",
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 12)),
                                SizedBox(height: 4),
                                Text("—",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("📶 Status",
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text(
                                  deviceOnline ? "Online" : "Offline",
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                if (!deviceFound)
                  const Text(
                    "Please return to pairing and try again.",
                    style: TextStyle(color: Colors.redAccent, fontSize: 14),
                  )
                else
                  Column(
                    children: const [
                      SizedBox(height: 40),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Connecting...",
                          style:
                              TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
