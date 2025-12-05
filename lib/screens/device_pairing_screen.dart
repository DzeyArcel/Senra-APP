import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  @override
  void initState() {
    super.initState();

    // Auto-fill from QR
    if (widget.scannedDeviceId != null &&
        widget.scannedDeviceId!.trim().isNotEmpty) {
      _deviceIdController.text = widget.scannedDeviceId!.trim().toUpperCase();
      WidgetsBinding.instance.addPostFrameCallback((_) => _pairDevice());
    }
  }

  // ======================================================
  // QR SCANNER
  // ======================================================
  Future<void> _scanQr() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );

    if (result != null && result is String) {
      _deviceIdController.text = result.trim().toUpperCase();
      _pairDevice();
    }
  }

  // ======================================================
  // DEVICE PAIRING LOGIC
  // ======================================================
  Future<void> _pairDevice() async {
    final deviceId =
        _deviceIdController.text.trim().toUpperCase().replaceAll(" ", "");

    if (deviceId.isEmpty) {
      _toast("Please enter a Device ID (e.g. SENRA-001)");
      return;
    }

    setState(() => _isPairing = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final caregiverId = prefs.getString("caregiverId") ?? "";

      if (caregiverId.isEmpty) {
        _toast("Session expired. Please restart the app.");
        setState(() => _isPairing = false);
        return;
      }

      final firestore = FirebaseFirestore.instance;

      // 1️⃣ Check if device exists
      final deviceSnap =
          await firestore.collection("devices").doc(deviceId).get();

      if (!deviceSnap.exists) {
        _toast("Device not found. Please check the ID.");
        setState(() => _isPairing = false);
        return;
      }

      final dev = deviceSnap.data()!;
      final pairedTo = dev["paired_to"];

      // 2️⃣ If paired to someone else
      if (pairedTo != null && pairedTo != "" && pairedTo != caregiverId) {
        _toast("This device is already paired to another caregiver.");
        setState(() => _isPairing = false);
        return;
      }

      // 3️⃣ Fetch caregiver details
      final caregiverSnap =
          await firestore.collection("caregivers").doc(caregiverId).get();

      final caregiver = caregiverSnap.data() ?? {};
      final caregiverName = caregiver["name"] ?? "";
      final caregiverPhone = caregiver["phone"] ?? "";

      // 4️⃣ Update device
      await firestore.collection("devices").doc(deviceId).set({
        "device_id": deviceId,
        "paired_to": caregiverId,
        "paired_at": FieldValue.serverTimestamp(),
        "status": "offline",
        "batteryLevel": dev["batteryLevel"] ?? 0,
        "lastSync": FieldValue.serverTimestamp(),
        "ownerId": caregiverId,
        "ownerName": caregiverName,
        "ownerPhone": caregiverPhone,
        "device_name": dev["device_name"] ?? "Senra Wearable",
      }, SetOptions(merge: true));

      // 5️⃣ Update caregiver profile
      await firestore
          .collection("caregivers")
          .doc(caregiverId)
          .update({"pairedDevice": deviceId});

      prefs.setString("pairedDevice", deviceId);

      if (!mounted) return;

      // 6️⃣ Navigate
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DeviceFoundScreen()),
      );
    } catch (e) {
      debugPrint("Pairing error: $e");
      if (mounted) _toast("Failed to pair. Please try again.");
    } finally {
      if (mounted) setState(() => _isPairing = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  // ======================================================
  // UI
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ==============================================================  
                  //   BACK BUTTON (FIXED → GO TO CAREGIVER INFO)
                  // ==============================================================
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            "/caregiver-info",
                            (route) => false,
                          );
                        },
                        icon: const Icon(Icons.arrow_back, color: Colors.white70),
                      ),
                      const Text(
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
                      "Your Senra wearable will send fall alerts and\n"
                      "location updates directly to this app.",
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
                        hintText: "Enter Device ID (e.g., SENRA-001)",
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
