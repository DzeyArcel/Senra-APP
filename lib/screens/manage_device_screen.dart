import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ManageDeviceScreen extends StatefulWidget {
  const ManageDeviceScreen({super.key});

  @override
  State<ManageDeviceScreen> createState() => _ManageDeviceScreenState();
}

class _ManageDeviceScreenState extends State<ManageDeviceScreen> {
  String? deviceId;

  @override
  void initState() {
    super.initState();
    _loadPairedDevice();
  }

  // ---------------------------------------------------------
  // LOAD DEVICE FROM SHAREDPREFS (Senra ecosystem)
  // ---------------------------------------------------------
  Future<void> _loadPairedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final paired = prefs.getString("pairedDevice");

    if (paired != null && paired.isNotEmpty) {
      setState(() => deviceId = paired);
    }
  }

  // ---------------------------------------------------------
  // UNLINK DEVICE — resets both caregiver + device
  // ---------------------------------------------------------
  Future<void> _unlinkDevice() async {
    if (deviceId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final caregiverId = prefs.getString("caregiverId");

    if (caregiverId == null) return;

    // caregiver → reset pairedDevice
    await FirebaseFirestore.instance
        .collection("caregivers")
        .doc(caregiverId)
        .update({"pairedDevice": ""});

    // device → reset paired_to
    await FirebaseFirestore.instance
        .collection("devices")
        .doc(deviceId)
        .update({"paired_to": ""});

    // clear session
    await prefs.setString("pairedDevice", "");

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Device unlinked successfully"),
        backgroundColor: Colors.redAccent,
      ),
    );

    Navigator.pushNamedAndRemoveUntil(
        context, "/device-pairing", (route) => false);
  }

  // ---------------------------------------------------------
  // REQUEST WIFI RESET
  // ---------------------------------------------------------
  Future<void> _changeWifi() async {
    if (deviceId == null) return;

    await FirebaseFirestore.instance
        .collection("devices")
        .doc(deviceId)
        .update({"adminCommand": "reset_wifi"});

    Navigator.pushNamed(context, "/wifi-config");
  }

  // ---------------------------------------------------------
  // TIME → readable format
  // ---------------------------------------------------------
  String _timeAgo(dynamic val) {
    if (val == null) return "Unknown";

    DateTime? dt;
    if (val is Timestamp) dt = val.toDate();
    if (val is String) dt = DateTime.tryParse(val);

    if (dt == null) return "Unknown";

    final minutes = DateTime.now().difference(dt).inMinutes;
    if (minutes < 1) return "Just now";
    if (minutes == 1) return "1 min ago";
    return "$minutes min ago";
  }

  @override
  Widget build(BuildContext context) {
    if (deviceId == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0E1625),
        body: Center(
          child: Text(
            "No paired device found",
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

          final raw = snapshot.data!.data() as Map<String, dynamic>? ?? {};

          // -----------------------------------------------------
          // SAFE FIRESTORE READS
          // -----------------------------------------------------
          final name = raw["device_name"] ?? "Senra Device";
          final firmware = raw["firmware"] ?? "v1.0.0";

          // battery
          final battery = raw["batteryLevel"] ??
              raw["battery"] ??
              0;

          // last sync
          final lastSyncText = _timeAgo(raw["lastSync"]);

          // signal strength (GSM)
          final signal = raw["signal"]?.toString() ?? "Unknown";

          // online rule — 20 seconds
          bool online = false;
          if (raw["lastSync"] != null) {
            DateTime? dt;
            if (raw["lastSync"] is Timestamp) {
              dt = raw["lastSync"].toDate();
            } else if (raw["lastSync"] is String) {
              dt = DateTime.tryParse(raw["lastSync"]);
            }
            if (dt != null) {
              online = DateTime.now().difference(dt).inSeconds < 20;
            }
          }

          // -----------------------------------------------------
          // UI
          // -----------------------------------------------------
          return SafeArea(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // HEADER
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white70),
                      ),
                      const SizedBox(width: 6),
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

                  // DEVICE INFO
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF162233),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        Row(
                          children: const [
                            Icon(Icons.watch_outlined,
                                color: Color(0xFF33B5FF), size: 22),
                            SizedBox(width: 10),
                            Text(
                              "Device Information",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),
                        Container(height: 1, color: Colors.white12),
                        const SizedBox(height: 18),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _InfoColumn(label: "Device Name", value: name),
                            _InfoColumn(label: "Device ID", value: deviceId!),
                          ],
                        ),

                        const SizedBox(height: 18),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _InfoColumn(
                                label: "Battery Level",
                                value: "$battery%"),
                            _InfoColumn(
                                label: "Last Sync", value: lastSyncText),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // CONNECTION STATUS
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF162233),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        Row(
                          children: const [
                            Icon(Icons.wifi,
                                color: Color(0xFF33B5FF), size: 22),
                            SizedBox(width: 10),
                            Text(
                              "Connection Status",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),
                        Container(height: 1, color: Colors.white12),
                        const SizedBox(height: 18),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Connected",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                            ),
                            Text(
                              online ? "Active" : "Offline",
                              style: TextStyle(
                                color: online
                                    ? Colors.lightGreenAccent
                                    : Colors.redAccent,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 22),

                        // BUTTONS
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: _changeWifi,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFF33B5FF),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      "Change Wi-Fi",
                                      style: TextStyle(
                                        color: Color(0xFF33B5FF),
                                        fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 12),

                            Expanded(
                              child: GestureDetector(
                                onTap: _unlinkDevice,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.redAccent,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      "Unlink Device",
                                      style: TextStyle(
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // FOOTER
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF162233),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "Device Status",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 18),

                        _InfoColumn(
                            label: "Signal Strength", value: signal),

                        const SizedBox(height: 14),

                        _InfoColumn(
                            label: "Firmware Version", value: firmware),

                        const SizedBox(height: 8),
                      ],
                    ),
                  ),

                  const SizedBox(height: 50),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// -------------------------------------------------------------
// REUSABLE COLUMN
// -------------------------------------------------------------
class _InfoColumn extends StatelessWidget {
  final String label;
  final String value;

  const _InfoColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14)),
      ],
    );
  }
}
