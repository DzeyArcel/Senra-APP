// ***************************************************************
// SENRA APP — DASHBOARD (UI/UX FIXED, LOGIC SAFE)
// Fully compatible with StartupRouter, AlertScreen, FW V17.3
// PRODUCTION UPDATE: Improved status logic, reliability, emergency handling
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

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  String? deviceId;
  String caregiverId = "";
  String cleanDeviceId = "";

  bool allowLocation = true;
  bool allowVibration = true;

  StreamSubscription? alertListener;
  StreamSubscription? privacyListener;
  StreamSubscription? deviceListener;
  bool alertOpened = false;
  String? lastProcessedAlertId;

  


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadIds();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    alertListener?.cancel();
    privacyListener?.cancel();
    deviceListener?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh status when app resumes to catch up on missed updates
    if (state == AppLifecycleState.resumed && mounted && cleanDeviceId.isNotEmpty) {
      _refreshDeviceStatus();
    }
  }

  // ---------------------------------------------------------------
  // LOAD IDS
  // ------------------------------------------------------------------
  Future<void> _loadIds() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) Navigator.pushReplacementNamed(context, "/welcome");
      return;
    }

    caregiverId = user.uid;
    deviceId = prefs.getString("pairedDevice") ?? "";

    if (deviceId!.isEmpty) {
      if (mounted) Navigator.pushReplacementNamed(context, "/device-pairing");
      return;
    }

    cleanDeviceId = deviceId!.replaceAll('"', "").trim();

    await NotificationInitializer.init();
    _syncPrivacySettings();
 

    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted);
    });

    if (mounted) setState(() {});
  }


  // ------------------------------------------------------------------
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


  bool _isOnline(Map<String, dynamic> data) {
    // If resetting, consider offline
    if (data["status"] == "resetting") return false;

    final rawSync = data["lastSync"];
    DateTime? t;

    // Support both Timestamp and ISO string formats, convert to UTC
    if (rawSync is Timestamp) {
      t = rawSync.toDate().toUtc();
    } else if (rawSync is String) {
      final parsed = DateTime.tryParse(rawSync);
      if (parsed != null) t = parsed.toUtc();
    }

    if (t == null) return false;

    final now = DateTime.now().toUtc();
    final diff = now.difference(t).inSeconds;
    
    // Device offline if last sync is older than 90 seconds
    return diff <= 90;
  }

  // ------------------------------------------------------------------
  // IMPROVED: Emergency states keep device appearing online
  // ------------------------------------------------------------------
  bool _effectiveOnline(bool rawOnline, String fallStatus) {
    // Emergency states always appear online even if sync is stale
    final bool inEmergency = fallStatus == "pending" || fallStatus == "sent";
    if (inEmergency) return true;
    return rawOnline;
  }

  // ------------------------------------------------------------------
  // NEW: Force refresh when app resumes
  // ------------------------------------------------------------------
  Future<void> _refreshDeviceStatus() async {
    if (cleanDeviceId.isEmpty) return;
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection("devices")
          .doc(cleanDeviceId)
          .get();
          
      if (doc.exists && mounted) {
        // Trigger rebuild with fresh data
        setState(() {});
      }
    } catch (e) {
      debugPrint('Refresh error: $e');
    }
  }

  // ------------------------------------------------------------------
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
              .snapshots(includeMetadataChanges: true), // Faster updates
          builder: (context, snap) {
            if (!snap.hasData) return _loading();

            final data = snap.data!.data() as Map<String, dynamic>?;
            if (data == null) return _noData();

            // Extract status fields once
            final String fallStatus = data["fallStatus"] ?? "none";
            
            // Determine online status with 90s threshold
            final bool rawOnline = _isOnline(data);
            
            // Emergency states (pending/sent) force online appearance
            final bool online = _effectiveOnline(rawOnline, fallStatus);
            
            // Legacy compatibility
            final bool fallDetected = fallStatus == "pending" || fallStatus == "sent";

            return _dashboardUI(data, online, fallDetected, fallStatus);
          },
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
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

  // ------------------------------------------------------------------
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

  // ------------------------------------------------------------------
  // IMPROVED: Status card with strict priority logic
  // ------------------------------------------------------------------
  Widget _statusCard(
    Map<String, dynamic> data,
    bool online,
    bool fallDetected,
    String fallStatus,
    int battery,
  ) {
    final lastSync = data["lastSync"];
    final bool isResetting = data["status"] == "resetting";

    // Strict priority detection (single source of truth)
    final bool emergencyDetected = fallStatus == "pending";
    final bool emergencyActive = fallStatus == "sent";
final bool cancelled = fallStatus == "cancelled_by_device";
final bool cooldown = fallStatus == "cooldown";


    // ---------------- HEADLINE LOGIC (Priority-based) ----------------
    final String headline = isResetting
    ? "Reconnecting — please wait"
    : emergencyDetected
        ? "Possible fall detected"
       : emergencyActive
    ? "Emergency alert active"
: cancelled
    ? "Alert cancelled"
: cooldown
    ? "System stabilizing"
                : !online
                    ? "Device offline"
                    : "Monitoring active";

    // ---------------- BADGE TEXT LOGIC (Priority-based) ----------------
    final String badgeText = isResetting
    ? "Reconnecting"
    : emergencyDetected
        ? "Possible Fall"
       : emergencyActive
    ? "Emergency"
: cancelled
    ? "Canceled"
: cooldown
    ? "Cooldown"
                : !online
                    ? "Offline"
                    : "Online";

    // ---------------- BADGE COLOR LOGIC ----------------
    final Color badgeColor = isResetting
    ? Colors.orangeAccent
    : emergencyDetected
        ? Colors.orangeAccent
       : emergencyActive
            ? Colors.redAccent
                : cancelled
                  ? Colors.grey
                     : cooldown
                       ? Colors.blueAccent
                         : !online
                          ? Colors.grey
                            : Colors.lightGreenAccent;

    // ---------------- DESCRIPTION LOGIC ----------------
    final String description = isResetting
    ? "The Senra wearable is reconnecting."
    : emergencyDetected
        ? "A possible fall was detected. The user has a few seconds to cancel."
        : emergencyActive
            ? "Emergency alert has been triggered and caregivers are being notified."
        : cancelled
            ? "The alert was cancelled directly from the wearable device."
        : cooldown
            ? "The system is temporarily stabilizing to prevent repeated alerts."
        : !online
            ? "The device is temporarily offline."
            : "The Senra wearable is actively monitoring for falls.";

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
                  Icon(
                    Icons.battery_full_rounded,
                    color: battery > 20 ? Colors.lightGreenAccent : Colors.redAccent,
                  ),
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
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
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

  // ------------------------------------------------------------------
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