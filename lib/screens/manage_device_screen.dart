// ============================================================
// ManageDeviceScreen.dart — FINAL ECOSYSTEM VERSION
// - Auth-safe (FirebaseAuth UID)
// - Unlink device safe
// - Change Wi-Fi password (reset_wifi)
// - StartupRouter aligned
// ============================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ManageDeviceScreen extends StatefulWidget {
  const ManageDeviceScreen({super.key});

  @override
  State<ManageDeviceScreen> createState() => _ManageDeviceScreenState();
}

class _ManageDeviceScreenState extends State<ManageDeviceScreen> {
  String? deviceId;

  // ==========================================================
  // INIT
  // ==========================================================
  @override
  void initState() {
    super.initState();
    _loadPairedDevice();
  }

  // ==========================================================
  // LOAD PAIRED DEVICE (LOCAL CACHE)
  // ==========================================================
  Future<void> _loadPairedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final paired = prefs.getString("pairedDevice");

    if (paired != null && paired.isNotEmpty) {
      setState(() => deviceId = paired);
    }
  }

  // ==========================================================
  // 🔌 UNLINK DEVICE — AUTH + ECOSYSTEM SAFE
  // ==========================================================
  Future<void> _unlinkDevice() async {
    if (deviceId == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();

    try {
      // 1️⃣ Clear caregiver link
      await FirebaseFirestore.instance
          .collection("caregivers")
          .doc(user.uid)
          .update({
        "pairedDevice": "",
      });

      // 2️⃣ Clear device link
      await FirebaseFirestore.instance
          .collection("devices")
          .doc(deviceId)
          .update({
        "paired_to": "",
      });

      // 3️⃣ Clear local state
      await prefs.remove("pairedDevice");
      await prefs.setBool("needsWifiSetup", true);

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        "/device-pairing",
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to unlink device: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // ==========================================================
  // 📶 CHANGE WI-FI PASSWORD (RESET FLOW)
  // ==========================================================
  Future<void> _changeWifi() async {
    if (deviceId == null) return;

    final prefs = await SharedPreferences.getInstance();

    // Force Wi-Fi setup route
    await prefs.setBool("needsWifiSetup", true);

    // Loading overlay
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    try {
      // 🔥 ONLY FIELD FIRMWARE LISTENS TO
      await FirebaseFirestore.instance
          .collection("devices")
          .doc(deviceId)
          .update({
        "adminCommand": "reset_wifi",
      });

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;
      Navigator.pop(context);

      Navigator.pushNamed(context, "/wifi-config");
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to reset Wi-Fi: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // ==========================================================
  // TIME FORMATTER
  // ==========================================================
  String _timeAgo(dynamic value) {
    if (value == null) return "—";

    DateTime? dt;
    if (value is Timestamp) dt = value.toDate();
    if (value is String) dt = DateTime.tryParse(value);

    if (dt == null) return "—";

    final minutes = DateTime.now().difference(dt).inMinutes;
    if (minutes < 1) return "Just now";
    if (minutes == 1) return "1 min ago";
    return "$minutes min ago";
  }

  // ==========================================================
  // UI
  // ==========================================================
  @override
  Widget build(BuildContext context) {
    if (deviceId == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0E1625),
        body: Center(
          child: Text(
            "No paired Senra device.",
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0E1625),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection("devices")
            .doc(deviceId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          final raw =
              snapshot.data!.data() as Map<String, dynamic>? ?? {};

          final name = raw["device_name"] ?? "Senra Wearable";
          final firmware = raw["firmware"] ?? "v1.0.0";
          final battery = raw["batteryLevel"] ?? 0;
          final lastSyncText = _timeAgo(raw["lastSync"]);

          bool online = false;
          if (raw["lastSync"] != null) {
            DateTime? dt;
            if (raw["lastSync"] is Timestamp) {
              dt = raw["lastSync"].toDate();
            } else if (raw["lastSync"] is String) {
              dt = DateTime.tryParse(raw["lastSync"]);
            }
            if (dt != null) {
              online = DateTime.now().difference(dt).inSeconds < 30;
            }
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white70),
                      ),
                      const Text(
                        "Manage Device",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  _card(
                    title: "Device Information",
                    icon: Icons.watch_outlined,
                    children: [
                      _rowInfo("Device Name", name),
                      _rowInfo("Device ID", deviceId!),
                      _rowInfo("Battery Level", "$battery%"),
                      _rowInfo("Last Sync", lastSyncText),
                    ],
                  ),

                  const SizedBox(height: 22),

                  _card(
                    title: "Connection Status",
                    icon: Icons.wifi,
                    children: [
                      _rowInfo(
                        "Status",
                        online ? "Online" : "Offline",
                        valueColor: online
                            ? Colors.lightGreenAccent
                            : Colors.redAccent,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _btnOutlined(
                              text: "Change Wi-Fi",
                              color: const Color(0xFF33B5FF),
                              onTap: _changeWifi,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _btnOutlined(
                              text: "Unlink Device",
                              color: Colors.redAccent,
                              onTap: _unlinkDevice,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  _card(
                    title: "Device Status",
                    icon: Icons.memory_rounded,
                    children: [
                      _rowInfo("Firmware Version", firmware),
                    ],
                  ),

                  const SizedBox(height: 60),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================================
  // UI HELPERS
  // ==========================================================
  Widget _card({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF162233),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF33B5FF), size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(height: 1, color: Colors.white12),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }

  Widget _rowInfo(String label, String value,
      {Color valueColor = Colors.white}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _btnOutlined({
    required String text,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
