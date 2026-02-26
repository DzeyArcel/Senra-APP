// ***************************************************************
// SENRA APP — DASHBOARD (UI/UX FIXED, LOGIC SAFE)
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

  bool allowLocation = true;
  bool allowVibration = true;

  StreamSubscription? alertListener;
  StreamSubscription? privacyListener;
  bool alertOpened = false;

  @override
  void initState() {
    super.initState();
    _loadIds();
  }

  // ---------------------------------------------------------------
  // LOAD IDS
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

    if (deviceId!.isEmpty) {
      Navigator.pushReplacementNamed(context, "/device-pairing");
      return;
    }

    cleanDeviceId = deviceId!.replaceAll('"', "").trim();

    await NotificationInitializer.init();
    _syncPrivacySettings();

    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _listenToAlerts();
    });

    setState(() {});
  }

  // ---------------------------------------------------------------
  void _syncPrivacySettings() {
    privacyListener?.cancel();

    privacyListener = FirebaseFirestore.instance
        .collection("caregivers")
        .doc(caregiverId)
        .snapshots()
        .listen((doc) {
      if (!doc.exists || !mounted) return;

      final data = doc.data()!;
      setState(() {
        allowLocation = data["locationSharing"] ?? true;
        allowVibration = data["emergencyVibration"] ?? true;
      });
    });
  }

  // ---------------------------------------------------------------
  void _listenToAlerts() {
    alertListener = FirebaseFirestore.instance
        .collection("alerts")
        .where("deviceId", isEqualTo: cleanDeviceId)
        .orderBy("timestamp", descending: true)
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
        if (allowVibration) {
          HapticFeedback.heavyImpact();
        }

        await FirebaseFirestore.instance
            .collection("alerts")
            .doc(doc.id)
            .update({"delivered": true});

        await Navigator.pushNamed(
          context,
          "/alert",
          arguments: {
            "alertId": doc.id,
            "deviceId": cleanDeviceId,
            "location": allowLocation
                ? (data["location"] ?? "Unknown")
                : "Location hidden",
            "lat": allowLocation ? (data["lat"] ?? 0.0) : 0.0,
            "lng": allowLocation ? (data["lng"] ?? 0.0) : 0.0,
            "mapURL": allowLocation ? (data["mapURL"] ?? "") : "",
            "fallType": data["fallType"] ?? "Fall Detected",
            "startSeconds": 8,
          },
        );
      } finally {
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
bool _isOnline(Map<String, dynamic> data) {
  if (data["status"] == "resetting") return false;

  final rawSync = data["lastSync"];
  DateTime? t;

  if (rawSync is Timestamp) t = rawSync.toDate();
  if (rawSync is String) t = DateTime.tryParse(rawSync);
  if (t == null) return false;

  final diff = DateTime.now().difference(t).inSeconds;

  // 🔥 KEY FIX:
  // Allow longer silence BEFORE fallDetected flips true
  return diff <= 60; // was 20
}

  bool _effectiveOnline(bool online, bool fallDetected) {
    if (fallDetected) return true;
    return online;
  }

  // ---------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (deviceId == null || cleanDeviceId.isEmpty) {
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

            final fallDetected = data["fallDetected"] == true &&
                data["fallStatus"] != "cancelled_by_device";

            final rawOnline = _isOnline(data);
            final online = _effectiveOnline(rawOnline, fallDetected);

            return _dashboardUI(data, online, fallDetected);
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
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

  // ---------------------------------------------------------------
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
                style: TextStyle(color: Colors.white70)),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.settings, color: Colors.white70),
          onPressed: () => Navigator.pushNamed(context, "/settings"),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------
  Widget _statusCard(
  Map<String, dynamic> data,
  bool online,
  bool fallDetected,
  int battery,
) {
  final lastSync = data["lastSync"];

  final bool isResetting = data["status"] == "resetting";
  final bool contactingEmergency =
      fallDetected && data["fallStatus"] == "pending";

  // ---------------- STATUS TEXT ----------------
  final String headline = isResetting
      ? "Reconnecting — please wait"
      : fallDetected
          ? contactingEmergency
              ? "Handling emergency"
              : "Emergency detected"
          : online
              ? "Monitoring active"
              : "Temporarily offline";

  final String badgeText = fallDetected
      ? contactingEmergency
          ? "Notifying"
          : "Emergency"
      : isResetting
          ? "Reconnecting"
          : online
              ? "Online"
              : "Offline";

 final Color badgeColor = fallDetected
    ? contactingEmergency
        ? Colors.orangeAccent
        : Colors.redAccent
    : isResetting
        ? Colors.orangeAccent
        : online
            ? Colors.lightGreenAccent
            : Colors.orangeAccent;

  // ---------------- DESCRIPTION ----------------
  final String description = fallDetected
      ? contactingEmergency
          ? "Contacting emergency services and caregivers. SMS delivery depends on mobile signal."
          : "Emergency contacts have been notified. Please follow the alert instructions."
      : isResetting
          ? "The Senra wearable is reconnecting to resume monitoring."
          : online
              ? "The Senra wearable detects falls and sends alerts to this app."
              : "The device is temporarily offline. Monitoring will resume once connected.";

  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFF162233),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ================= HEADER =================
        const Row(
          children: [
            Icon(Icons.shield_outlined, color: Color(0xFF33B5FF)),
            SizedBox(width: 10),
            Text(
              "Device Status",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),
        // (rest of your widget stays the same)

        // ================= STATUS ROW =================
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                headline,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  color: badgeColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // ================= DESCRIPTION =================
        Text(
          description,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            height: 1.4,
          ),
        ),

        const SizedBox(height: 16),
        Container(height: 1, color: Colors.white12),
        const SizedBox(height: 14),

        // ================= BATTERY + SYNC =================
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.battery_full_rounded,
                    color: Colors.lightGreenAccent),
                const SizedBox(width: 6),
                Text(
                  "Battery $battery%",
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.access_time, color: Colors.blueAccent),
                const SizedBox(width: 6),
                Text(
                  "Last sync: ${_formatTime(lastSync)}",
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ],
        ),

        // ================= FALL WARNING =================
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
                Text(
                  "Fall detected",
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

  // ---------------------------------------------------------------
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

  // ---------------------------------------------------------------
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
                  color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          _quickItem(Icons.show_chart, "Activity Log",
              "View history", "/activity-history"),
          _quickItem(Icons.people, "Emergency Contacts",
              "Manage contacts", "/emergency-contacts"),
          _quickItem(Icons.location_on, "Location",
              "Track location", "/location-tracking"),
        ],
      ),
    );
  }

  Widget _quickItem(
      IconData icon, String title, String subtitle, String route) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
                        fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: const TextStyle(color: Colors.white54)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _loading() => const Scaffold(
        backgroundColor: Color(0xFF0E1625),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF33B5FF)),
        ),
      );

  Widget _noData() => const Scaffold(
        backgroundColor: Color(0xFF0E1625),
        body: Center(
          child: Text("Waiting for device data...",
              style: TextStyle(color: Colors.white54)),
        ),
      );
}