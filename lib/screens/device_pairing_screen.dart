// ============================================================
// DevicePairingScreen.dart — FINAL STABLE VERSION
// QR FIXED • UID SAFE • ESP32 SAFE • UI UNCHANGED
// ============================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'device_found_screen.dart';
import 'qr_scanner_screen.dart';

class DevicePairingScreen extends StatefulWidget {
  final String? scannedDeviceId;

  const DevicePairingScreen({
    super.key,
    this.scannedDeviceId,
  });

  @override
  State<DevicePairingScreen> createState() => _DevicePairingScreenState();
}

class _DevicePairingScreenState extends State<DevicePairingScreen> {
  final TextEditingController _deviceIdController = TextEditingController();
  bool _isPairing = false;

  // ======================================================
  // INIT
  // ======================================================
  @override
  void initState() {
    super.initState();

    if (widget.scannedDeviceId?.trim().isNotEmpty == true) {
      _deviceIdController.text =
          widget.scannedDeviceId!.trim().toUpperCase().replaceAll(" ", "");
    }
  }

  // ======================================================
  // 🔥 SEND CAREGIVER UID TO ESP32 (SAFE)
  // ======================================================
  Future<void> _sendCaregiverUidToDevice(String? deviceIp) async {
    if (deviceIp == null || deviceIp.isEmpty) {
      debugPrint("⚠️ No device IP — skipping UID push");
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint("❌ No Firebase UID — cannot send");
      return;
    }

    final url = Uri.parse('http://$deviceIp/setcaregiver?id=$uid');

    try {
      final res = await http.get(url).timeout(
        const Duration(seconds: 5),
      );

      if (res.statusCode == 200) {
        debugPrint("✅ Caregiver UID sent to ESP32");
      } else {
        debugPrint("❌ ESP32 rejected UID (${res.statusCode})");
      }
    } catch (e) {
      debugPrint("❌ UID send failed: $e");
    }
  }

  // ======================================================
  // QR SCAN — ONLY FILLS DEVICE ID
  // ======================================================
  Future<void> _scanQr() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );

    if (result != null && result is String) {
      setState(() {
        _deviceIdController.text =
            result.trim().toUpperCase().replaceAll(" ", "");
      });
    }
  }

  // ======================================================
  // PAIR DEVICE
  // ======================================================
  Future<void> _pairDevice() async {
    final deviceId =
        _deviceIdController.text.trim().toUpperCase().replaceAll(" ", "");

    if (deviceId.isEmpty) {
      _toast("Please enter a Device ID.");
      return;
    }

    setState(() => _isPairing = true);

    try {
      final caregiverId = FirebaseAuth.instance.currentUser?.uid;
      if (caregiverId == null) {
        _toast("Please log in again.");
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final firestore = FirebaseFirestore.instance;

      // 1️⃣ Fetch device
      final deviceSnap =
          await firestore.collection("devices").doc(deviceId).get();

      if (!deviceSnap.exists) {
        _toast("Device not found.");
        return;
      }

      final dev = deviceSnap.data()!;
      final pairedTo = (dev["paired_to"] ?? "").toString();

      // 2️⃣ Block if paired elsewhere
      if (pairedTo.isNotEmpty && pairedTo != caregiverId) {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove("pairedDevice");
  await prefs.setBool("needsWifiSetup", true);

  _toast("This device is already paired to another caregiver.");
  return;
}


      // 3️⃣ Fetch caregiver info
      final caregiverSnap =
          await firestore.collection("caregivers").doc(caregiverId).get();
      final caregiver = caregiverSnap.data() ?? {};

      // 4️⃣ Update device
      await firestore.collection("devices").doc(deviceId).set({
        "device_id": deviceId,
        "paired_to": caregiverId,
        "ownerId": caregiverId,
        "ownerName": caregiver["name"] ?? "",
        "ownerPhone": caregiver["phone"] ?? "",
        "paired_at": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 5️⃣ Push UID to ESP32 (if reachable)
      await _sendCaregiverUidToDevice(dev["ip"]);

      // 6️⃣ Update caregiver
      await firestore.collection("caregivers").doc(caregiverId).update({
        "pairedDevice": deviceId,
      });

      // 7️⃣ Save locally
      await prefs.setString("pairedDevice", deviceId);
      await prefs.setBool("needsWifiSetup", true);

      if (!mounted) return;

      // 8️⃣ Continue flow
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DeviceFoundScreen()),
      );
    } catch (e) {
      debugPrint("❌ Pairing error: $e");
      _toast("Failed to pair. Try again.");
    } finally {
      if (mounted) setState(() => _isPairing = false);
    }
  }

  // ======================================================
  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  // ======================================================
  // UI — UNCHANGED
  // ======================================================
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushNamedAndRemoveUntil(
          context,
          "/caregiver-info",
          (route) => false,
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0E1625),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
  children: const [
    Text(
      "Device Pairing",
      style: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
  ],
),
                const SizedBox(height: 25),
                const Text(
                  "Connect Your Senra Wearable",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Scan the QR code on your Senra device to link it.",
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _iconBox(Icons.watch),
                    const SizedBox(width: 18),
                    const Icon(Icons.arrow_forward,
                        color: Colors.white38, size: 20),
                    const SizedBox(width: 18),
                    _iconBox(Icons.phone_iphone),
                  ],
                ),
                const SizedBox(height: 30),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF162233),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    "Your Senra wearable will send fall alerts and location updates directly to this app.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                GestureDetector(
                  onTap: _scanQr,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF33B5FF),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.qr_code_scanner,
                              color: Colors.black87, size: 18),
                          SizedBox(width: 8),
                          Text(
                            "Scan QR Code",
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                Center(
                  child: Text(
                    "Or enter the device ID:",
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 15),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF101B2C),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: _deviceIdController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: "Enter Device ID (e.g., SNR-TEST-01)",
                      hintStyle: TextStyle(color: Colors.white38),
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: _isPairing ? null : _pairDevice,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF223247),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        _isPairing ? "Connecting..." : "Connect",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconBox(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF162233),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: Colors.white, size: 32),
    );
  }
}
