import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // ============= NEW FALL SYSTEM =============
  StreamSubscription<DocumentSnapshot>? _deviceListener;
  bool _fallScreenOpened = false;

  @override
  void initState() {
    super.initState();

    // Start listening after UI loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startDeviceFallListener();
    });
  }

  @override
  void dispose() {
    _deviceListener?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------
  // 🔥 LISTEN FOR fallDetected ON DEVICE DOCUMENT
  // ---------------------------------------------------------
  Future<void> _startDeviceFallListener() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString("pairedDevice");

    if (deviceId == null || deviceId.isEmpty) return;

    _deviceListener = FirebaseFirestore.instance
        .collection("devices")
        .doc(deviceId)
        .snapshots()
        .listen((snap) {
      if (!snap.exists || _fallScreenOpened) return;

      final data = snap.data() as Map<String, dynamic>;

      // SAFE fallDetected read
      bool fallDetected = false;
      final rawFall = data["fallDetected"];

      if (rawFall is bool) fallDetected = rawFall;
      if (rawFall is Map && rawFall["booleanValue"] is bool) {
        fallDetected = rawFall["booleanValue"];
      }

      if (!fallDetected) return;

      // Prevent double navigation
      _fallScreenOpened = true;

      // Extract location text
      final lat = data["lat"];
      final lng = data["lng"];
      final locationText =
          (lat != null && lng != null) ? "Lat: $lat, Lng: $lng" : "Location not ready";

      final mapURL = "https://www.google.com/maps?q=${lat ?? ''},${lng ?? ''}";

      // Navigate to your alert screen
      Navigator.pushNamed(
        context,
        "/alert",
        arguments: {
          "deviceId": deviceId,
          "location": locationText,
          "mapURL": mapURL,
        },
      ).then((_) {
        // Allow next alerts
        _fallScreenOpened = false;
      });
    });
  }

  // ---------------------------------------------------------
  // GET CAREGIVER → DEVICE ID
  // ---------------------------------------------------------
  Future<String?> _getPairedDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final caregiverId = prefs.getString("caregiverId");

    if (caregiverId == null || caregiverId.isEmpty) return null;

    final doc = await FirebaseFirestore.instance
        .collection("caregivers")
        .doc(caregiverId)
        .get();

    if (!doc.exists) return null;

    final pairedDevice = doc.data()?["pairedDevice"];
    return pairedDevice == "" ? null : pairedDevice;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _getPairedDeviceId(),
      builder: (context, snap) {
        if (!snap.hasData) return _loading();
        if (snap.data == null) return _noDevice();

        return _dashboard(context, snap.data!);
      },
    );
  }

  // ---------------------------------------------------------
  // MAIN DASHBOARD UI
  // ---------------------------------------------------------
  Widget _dashboard(BuildContext context, String deviceId) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1625),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Dashboard",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Your safety monitoring center",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white70),
                    onPressed: () => Navigator.pushNamed(context, "/settings"),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // DEVICE STATUS STREAM
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("devices")
                    .doc(deviceId)
                    .snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) return _statusLoadingCard();

                  final raw = snap.data!.data() as Map<String, dynamic>?;

                  if (raw == null) return _noDeviceDataCard();

                  // Battery
                  final int battery =
                      raw["batteryLevel"] ?? raw["battery"] ?? 0;

                  // Online detection by lastSync
                  bool online = false;
                  final lastSyncRaw = raw["lastSync"];
                  DateTime? lastSync;

                  if (lastSyncRaw is Timestamp) {
                    lastSync = lastSyncRaw.toDate();
                  } else if (lastSyncRaw is String) {
                    lastSync = DateTime.tryParse(lastSyncRaw);
                  }

                  if (lastSync != null) {
                    final diff =
                        DateTime.now().difference(lastSync).inSeconds;
                    online = diff <= 20;
                  }

                  final String lastSyncText = _formatTime(lastSyncRaw);

                  // fallDetected for small UI notification (not navigation)
                  bool fallDetected = false;
                  final rawFall = raw["fallDetected"];
                  if (rawFall is bool) fallDetected = rawFall;

                  return _statusCard(
                    online: online,
                    battery: battery,
                    lastSync: lastSyncText,
                    fallDetected: fallDetected,
                  );
                },
              ),

              const SizedBox(height: 26),

              _quickAccess(context),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  //---------------------------------------------------------
  // TIME FORMATTER
  //---------------------------------------------------------
  String _formatTime(dynamic value) {
    DateTime? dt;

    if (value is String) dt = DateTime.tryParse(value);
    if (value is Timestamp) dt = value.toDate();

    if (dt == null) return "Unknown";

    final diff = DateTime.now().difference(dt);

    if (diff.inSeconds < 60) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes} min ago";
    if (diff.inHours < 24) return "${diff.inHours} hours ago";

    return "${diff.inDays} days ago";
  }

  // ---------------------------------------------------------
  // STATUS CARD UI
  // ---------------------------------------------------------
  Widget _statusCard({
    required bool online,
    required int battery,
    required String lastSync,
    required bool fallDetected,
  }) {
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
              Icon(Icons.shield_outlined, color: Color(0xFF33B5FF), size: 22),
              SizedBox(width: 10),
              Text(
                "Device Status",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          if (!online)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withOpacity(0.25)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.wifi_off, color: Colors.redAccent, size: 18),
                  SizedBox(width: 8),
                  Text(
                    "Device is offline",
                    style: TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ],
              ),
            ),

          const Text(
            "The Senra wearable detects falls and sends alerts to this app",
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Device Connected —\nMonitoring Active",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  height: 1.3,
                ),
              ),
              Text(
                online ? "✓ Online" : "• Offline",
                style: TextStyle(
                  color: online ? Colors.lightGreenAccent : Colors.redAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          Container(height: 1, color: Colors.white12),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.battery_full_rounded,
                      color: Colors.lightGreenAccent, size: 18),
                  const SizedBox(width: 6),
                  Text("Battery $battery%",
                      style: const TextStyle(color: Colors.white)),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.access_time,
                      color: Colors.blueAccent, size: 18),
                  const SizedBox(width: 6),
                  Text("Last Sync: $lastSync",
                      style: const TextStyle(color: Colors.white)),
                ],
              ),
            ],
          ),

          const SizedBox(height: 18),

          Container(
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF1B2A3A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text("● Wearable",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 12,
                    )),
                const Icon(Icons.chevron_right, color: Colors.white38),
                const Text("● App",
                    style: TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
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
                  Text(
                    "Fall Detected!",
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
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

  // ---------------------------------------------------------
  // QUICK ACCESS
  // ---------------------------------------------------------
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
          const Text(
            "Quick Access",
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),

          _quickItem(
            icon: Icons.show_chart_rounded,
            title: "Activity Log",
            subtitle: "View history",
            onTap: () => Navigator.pushNamed(context, "/activity-history"),
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
            Icon(icon, color: const Color(0xFF33B5FF), size: 24),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    )),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // FALLBACK SCREENS
  // ---------------------------------------------------------
  Widget _loading() => const Scaffold(
        backgroundColor: Color(0xFF0E1625),
        body: Center(
            child: CircularProgressIndicator(color: Color(0xFF33B5FF))),
      );

  Widget _noDevice() => const Scaffold(
        backgroundColor: Color(0xFF0E1625),
        body: Center(
          child: Text(
            "No paired Senra device found.",
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );

  Widget _statusLoadingCard() => Container(
        height: 150,
        decoration: BoxDecoration(
          color: const Color(0xFF162233),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
            child: CircularProgressIndicator(color: Color(0xFF33B5FF))),
      );

  Widget _noDeviceDataCard() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF162233),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          "Waiting for device data...",
          style: TextStyle(color: Colors.white54),
        ),
      );
}
