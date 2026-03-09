// ***************************************************************
// SENRA APP — DASHBOARD (UI/UX FIXED, LOGIC SAFE)
// Fully compatible with StartupRouter, AlertScreen, FW V17.3
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
        .where("status", isEqualTo: "pending")
        .snapshots()
        .listen((snap) async {
      if (snap.docs.isEmpty) return;

      final doc = snap.docs.first;
      final data = doc.data();

      if (doc.metadata.hasPendingWrites) return;
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
            "fallType": "Fall Detected",
            "startSeconds": 8,
          },
        );
      } finally {
        alertOpened = false;
      }
    });
  }

  // ---------------------------------------------------------------
  bool _isOnline(Map<String, dynamic> data) {
    if (data["status"] == "resetting") return false;

    final rawSync = data["lastSync"];
    DateTime? t;

    if (rawSync is Timestamp) t = rawSync.toDate();
    if (rawSync is String) t = DateTime.tryParse(rawSync);
    if (t == null) return false;

    final diff = DateTime.now().toUtc().difference(t.toUtc()).inSeconds;
    return diff <= 120;
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

            // Extract status fields once
            final String fallStatus = data["fallStatus"] ?? "none";
            final bool fallDetected =
    fallStatus == "pending" ||
    fallStatus == "sent";

            final rawOnline = _isOnline(data);

// If emergency is active, device should still appear online
final bool fallActive =
    fallStatus == "pending" || fallStatus == "sent";

final online = _effectiveOnline(rawOnline, fallActive);

            return _dashboardUI(data, online, fallDetected, fallStatus);
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  Widget _dashboardUI(
    Map<String, dynamic> data, 
    bool online, 
    bool fallDetected,
    String fallStatus,
  ) {
    final battery = data["batteryLevel"] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 22),
          _statusCard(data, online, fallDetected, fallStatus, battery),
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
    String fallStatus,
    int battery,
  ) {
    final lastSync = data["lastSync"];
    final bool isResetting = data["status"] == "resetting";

    // Status detection (single source of truth)
    final bool cancelledByElder = fallStatus == "cancelled_by_device";
final bool emergencyDetected = fallStatus == "pending";
final bool notifyingContacts = fallStatus == "sent";
final bool smsFailed = fallStatus == "sms_failed";

    // ---------------- HEADLINE LOGIC ----------------
  final String headline = isResetting
    ? "Reconnecting — please wait"
    : smsFailed
        ? "Emergency alert — SMS delivery failed"
        : cancelledByElder
            ? "Emergency cancelled by the elder"
            : emergencyDetected
                ? "Emergency detected"
                : notifyingContacts
                    ? "Notifying emergency contacts"
                    : online
                        ? "Monitoring active"
                        : "Temporarily offline";

    // ---------------- BADGE TEXT LOGIC ----------------
  final String badgeText = smsFailed
    ? "SMS Failed"
    : cancelledByElder
        ? "Cancelled"
        : emergencyDetected
            ? "Emergency"
            : notifyingContacts
                ? "Notifying"
                : isResetting
                    ? "Reconnecting"
                    : online
                        ? "Online"
                        : "Offline";

    // ---------------- BADGE COLOR LOGIC ----------------
  final Color badgeColor = smsFailed
    ? Colors.orangeAccent
    : cancelledByElder
        ? Colors.orangeAccent
        : emergencyDetected
            ? Colors.redAccent
            : notifyingContacts
                ? Colors.orangeAccent
                : isResetting
                    ? Colors.orangeAccent
                    : online
                        ? Colors.lightGreenAccent
                        : Colors.grey;

    // ---------------- DESCRIPTION LOGIC ----------------
   final String description = smsFailed
    ? "SMS could not be delivered. The device may have weak mobile signal or SIM network issues."
    : cancelledByElder
        ? "The elder cancelled the alert from the wearable device."
        : emergencyDetected
            ? "Contacting emergency contacts via SMS. Delivery may take a few seconds depending on mobile signal."
            : notifyingContacts
                ? "Emergency contacts have been notified. Please follow the alert instructions."
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
          // Show warning for pending or sent states (not cancelled)
          if ((emergencyDetected || notifyingContacts) && !cancelledByElder) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
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