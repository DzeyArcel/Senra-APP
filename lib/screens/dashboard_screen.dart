// ***************************************************************
// SENRA APP — DASHBOARD (OPTIMIZED 2025 FINAL VERSION)
// Fully compatible with StartupRouter, AlertScreen, FW V14.7
// ***************************************************************

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_initializer.dart';
import 'package:firebase_auth/firebase_auth.dart';


class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {

  String? deviceId;
  String caregiverId = "";
  String cleanDeviceId = "";

  // 🔐 Privacy flags synced from caregiver settings
  bool allowLocation = true;
  bool allowVibration = true;

  StreamSubscription? alertListener;
  StreamSubscription? privacyListener;
  bool alertOpened = false; // IMPORTANT: never reset inside build()

  @override
  void initState() {
    super.initState();
    _loadIds();
  }

  // ---------------------------------------------------------------
  // LOAD CAREGIVER + DEVICE ID
  // ---------------------------------------------------------------
  Future<void> _loadIds() async {
    final prefs = await SharedPreferences.getInstance();

    final user = FirebaseAuth.instance.currentUser;

if (user == null) {
  Navigator.pushReplacementNamed(context, "/welcome");
  return;
}

caregiverId = user.uid;

    deviceId = prefs.getString("pairedDevice") ?? "";

    if (deviceId == null || deviceId!.isEmpty) {
      Navigator.pushReplacementNamed(context, "/device-pairing");
      return;
    }

    cleanDeviceId = deviceId!.replaceAll('"', "").trim();

    // ✅ INIT NOTIFICATIONS (safe: only runs once globally)
    if (caregiverId.isNotEmpty) {
      await NotificationInitializer.init();
    }

    // 🔁 Start syncing privacy preferences
    _syncPrivacySettings();

    // WAIT 350ms BEFORE STARTING LISTENER
 Future.delayed(const Duration(milliseconds: 350), () {
  if (!mounted) return;
  _listenToAlerts();
});

   if (mounted) {
  setState(() {});
}

  }

  // ---------------------------------------------------------------
  // 🔐 SYNC PRIVACY SETTINGS FROM CAREGIVER DOC
  // ---------------------------------------------------------------
  void _syncPrivacySettings() {
  if (caregiverId.isEmpty) return;

  privacyListener?.cancel();

  privacyListener = FirebaseFirestore.instance
      .collection("caregivers")
      .doc(caregiverId)
      .snapshots()
      .listen((doc) {
    if (!mounted || !doc.exists) return;

    final data = doc.data()!;

    if (!mounted) return;

    setState(() {
      allowLocation = data["locationSharing"] ?? true;
      allowVibration = data["emergencyVibration"] ?? true;
    });
  });
}


  // ---------------------------------------------------------------
  // REALTIME ALERT LISTENER — HANDLES MULTIPLE ALERTS SAFELY
  // ---------------------------------------------------------------
  void _listenToAlerts() {
    alertListener = FirebaseFirestore.instance
        .collection("alerts")
        .where("deviceId", isEqualTo: cleanDeviceId) // FILTER FIRST
        .orderBy("timestamp", descending: true) // THEN ORDER
        .limit(1)
        .snapshots()
        .listen((snap) async {

      if (snap.docs.isEmpty) return;

      final doc = snap.docs.first;
      final data = doc.data();

      if (data["delivered"] == true) return;
      if (data["status"] == "handled") return;
      if (data["status"] == "cancelled_by_device") return;

      if (alertOpened) return;
      alertOpened = true;

      try {
        // Load caregiver contacts
        final cgSnap = await FirebaseFirestore.instance
            .collection("caregivers")
            .doc(caregiverId)
            .get();

        List<Map<String, String>> contacts = [];
        if (cgSnap.exists) {
          final rawList = (cgSnap.data()?["contacts"] ?? []) as List<dynamic>;
          contacts = rawList.map((e) => Map<String, String>.from(e)).toList();
        }

        // 🧭 Respect Location Sharing
        final String safeLocation = allowLocation
            ? (data["location"] ?? "Unknown")
            : "Location hidden by privacy settings";

        final double safeLat = allowLocation ? (data["lat"] ?? 0.0).toDouble() : 0.0;
        final double safeLng = allowLocation ? (data["lng"] ?? 0.0).toDouble() : 0.0;
        final String safeMap = allowLocation ? (data["mapURL"] ?? "") : "";

        // 📳 Respect Vibration preference
        if (allowVibration) {
          HapticFeedback.heavyImpact();
        }

        // ✅ mark delivered BEFORE navigating (prevents double-trigger loops)
        await FirebaseFirestore.instance
            .collection("alerts")
            .doc(doc.id)
            .update({"delivered": true});

        // ✅ wait until user closes AlertScreen
        await Navigator.pushNamed(
          context,
          "/alert",
          arguments: {
            "alertId": doc.id,
            "deviceId": cleanDeviceId,
            "location": safeLocation,
            "lat": safeLat,
            "lng": safeLng,
            "mapURL": safeMap,
            "fallType": data["fallType"] ?? "Fall Detected",
            "contacts": contacts,
            "startSeconds": 8,
          },
        );

      } finally {
        // ✅ allow future alerts again
        alertOpened = false;
      }
    });
  }

 @override
void dispose() {
  alertListener?.cancel();
  privacyListener?.cancel();
  super.dispose();
}


  // ---------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (deviceId == null ||
        deviceId!.isEmpty ||
        caregiverId.isEmpty ||
        cleanDeviceId.isEmpty) {
      return _loading();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0E1625),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection("devices")
              .doc(cleanDeviceId)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) return _loading();

            final data = snap.data!.data() as Map<String, dynamic>?;

            if (data == null) return _noData();

            final online = _isOnline(data);

            final fallDetected = data["fallDetected"] == true &&
                data["fallStatus"] != "cancelled_by_device";

            return _dashboardUI(data, online, fallDetected);
          },
        ),
      ),
    );
  }

  // ------------------ UI HELPERS -----------------------

  Widget _loading() => const Scaffold(
        backgroundColor: Color(0xFF0E1625),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF33B5FF)),
        ),
      );

  Widget _noData() => const Scaffold(
        backgroundColor: Color(0xFF0E1625),
        body: Center(
          child: Text(
            "Waiting for device data...",
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );

  bool _isOnline(Map<String, dynamic> data) {
  // 🚫 Explicit device transition state
  if (data["status"] == "resetting") return false;

  final rawSync = data["lastSync"];
  DateTime? t;

  if (rawSync is Timestamp) t = rawSync.toDate();
  if (rawSync is String) t = DateTime.tryParse(rawSync);
  if (t == null) return false;

  return DateTime.now().difference(t).inSeconds <= 20;
}


  Widget _dashboardUI(
      Map<String, dynamic> data, bool online, bool fallDetected) {
    final battery = data["batteryLevel"] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 22),
          _statusCard(data, online, fallDetected, battery),
          const SizedBox(height: 26),
          _quickAccess(context),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Dashboard",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800)),
            SizedBox(height: 4),
            Text("Your safety monitoring center",
                style: TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.settings, color: Colors.white70),
          onPressed: () => Navigator.pushNamed(context, "/settings"),
        ),
      ],
    );
  }

  Widget _statusCard(Map<String, dynamic> data, bool online,
      bool fallDetected, int battery) {
    final lastSync = data["lastSync"];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF162233),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_outlined, color: Color(0xFF33B5FF)),
              SizedBox(width: 10),
              Text("Device Status",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
            ],
          ),

          const SizedBox(height: 8),

if (data["status"] == "resetting")
  _resettingAlert()
else if (!online)
  _offlineAlert(),



          const SizedBox(height: 6),
          const Text(
            "The Senra wearable detects falls and sends alerts to this app.",
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
  data["status"] == "resetting"
      ? "Reconnecting —\nPlease wait"
      : "Device Connected —\nMonitoring Active",

                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
              Text(
                online ? "✓ Online" : "• Offline",
                style: TextStyle(
                    color:
                        online ? Colors.lightGreenAccent : Colors.redAccent,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),

          const SizedBox(height: 20),
          Container(height: 1, color: Colors.white12),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Icon(Icons.battery_full_rounded,
                    color: Colors.lightGreenAccent),
                const SizedBox(width: 6),
                Text("Battery $battery%",
                    style: const TextStyle(color: Colors.white)),
              ]),
              Row(children: [
                const Icon(Icons.access_time, color: Colors.blueAccent),
                const SizedBox(width: 6),
                Text("Last Sync: ${_formatTime(lastSync)}",
                    style: const TextStyle(color: Colors.white)),
              ]),
            ],
          ),

          if (fallDetected) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.redAccent),
                  SizedBox(width: 10),
                  Text("Fall Detected!",
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _offlineAlert() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Icon(Icons.wifi_off, color: Colors.redAccent),
          SizedBox(width: 8),
          Text("Device is offline",
              style: TextStyle(color: Colors.redAccent)),
        ],
      ),
    );
  }

  Widget _resettingAlert() {
  return Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.orange.withOpacity(0.2),
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Row(
      children: [
        Icon(Icons.settings_backup_restore, color: Colors.orange),
        SizedBox(width: 8),
        Text(
          "Device is resetting Wi-Fi",
          style: TextStyle(color: Colors.orange),
        ),
      ],
    ),
  );
}


  String _formatTime(dynamic raw) {
    DateTime? t;
    if (raw is Timestamp) t = raw.toDate();
    if (raw is String) t = DateTime.tryParse(raw);
    if (t == null) return "Unknown";

    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes} min ago";
    if (diff.inHours < 24) return "${diff.inHours} hr ago";
    return "${diff.inDays} days ago";
  }

  Widget _quickAccess(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF162233),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Quick Access",
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15)),
          const SizedBox(height: 20),

          _quickItem(
            icon: Icons.show_chart_rounded,
            title: "Activity Log",
            subtitle: "View history",
            onTap: () =>
                Navigator.pushNamed(context, "/activity-history"),
          ),
          const SizedBox(height: 12),

          _quickItem(
            icon: Icons.people_alt_rounded,
            title: "Emergency Contacts",
            subtitle: "Manage contacts",
            onTap: () =>
                Navigator.pushNamed(context, "/emergency-contacts"),
          ),
          const SizedBox(height: 12),

          _quickItem(
            icon: Icons.location_on_rounded,
            title: "Location",
            subtitle: "Track location",
            onTap: () =>
                Navigator.pushNamed(context, "/location-tracking"),
          ),
        ],
      ),
    );
  }

  Widget _quickItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1B2A3A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF33B5FF)),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
