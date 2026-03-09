import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class LocationTrackingScreen extends StatefulWidget {
  const LocationTrackingScreen({super.key});

  @override
  State<LocationTrackingScreen> createState() =>
      _LocationTrackingScreenState();
}

class _LocationTrackingScreenState extends State<LocationTrackingScreen> {
  String? deviceId;
  String caregiverId = "";

  double? lat;
  double? lng;

  String address = "Waiting for GPS signal…";
  String lastUpdate = "—";

  bool loading = true;
  bool hasGps = false;
  bool gpsLocked = false;
  bool allowLocation = true;

  StreamSubscription? gpsSub;
  StreamSubscription? privacySub;

  @override
  void initState() {
    super.initState();
    _loadIds();
  }

  @override
  void dispose() {
    gpsSub?.cancel();
    privacySub?.cancel();
    super.dispose();
  }

  // ==========================================================
  // LOAD IDS
  // ==========================================================
  Future<void> _loadIds() async {
    final prefs = await SharedPreferences.getInstance();
    deviceId = prefs.getString("pairedDevice");

    final user = FirebaseAuth.instance.currentUser;
    caregiverId = user?.uid ?? "";

    if (deviceId == null || caregiverId.isEmpty) {
      setState(() => loading = false);
      return;
    }

    _listenToPrivacy();
    _listenToDevice(deviceId!);
  }

  // ==========================================================
  // PRIVACY LISTENER
  // ==========================================================
  void _listenToPrivacy() {
    privacySub = FirebaseFirestore.instance
        .collection("caregivers")
        .doc(caregiverId)
        .snapshots()
        .listen((doc) {
      if (!doc.exists) return;

      setState(() {
        allowLocation = doc.data()?["locationSharing"] ?? true;
      });
    });
  }

  // ==========================================================
  // DEVICE LISTENER
  // ==========================================================
  void _listenToDevice(String id) {
    gpsSub = FirebaseFirestore.instance
        .collection("devices")
        .doc(id)
        .snapshots()
        .listen((snap) {
      if (!snap.exists || snap.data() == null) {
        setState(() {
          hasGps = false;
          lat = null;
          lng = null;
          address = "No GPS data available";
        });
        return;
      }

      _applyGpsData(snap.data()!);
    });

    setState(() => loading = false);
  }

  // ==========================================================
  // APPLY GPS DATA
  // ==========================================================
  void _applyGpsData(Map<String, dynamic> data) {
    final double? newLat = (data["lat"] as num?)?.toDouble();
    final double? newLng = (data["lng"] as num?)?.toDouble();
    final bool newGpsLocked = data["gpsLocked"] == true;

    DateTime? ts;
    final rawSync = data["lastSync"];
    if (rawSync is Timestamp) ts = rawSync.toDate();
    if (rawSync is String) ts = DateTime.tryParse(rawSync);

    if (!allowLocation) {
      setState(() {
        hasGps = false;
        lat = null;
        lng = null;
        gpsLocked = false;
        address = "Location sharing is disabled";
        lastUpdate = "—";
      });
      return;
    }

    if (!newGpsLocked || newLat == null || newLng == null) {
      setState(() {
        hasGps = false;
        lat = null;
        lng = null;
        gpsLocked = false;
        address = "Searching GPS signal…";
        lastUpdate = "—";
      });
      return;
    }

    setState(() {
      lat = newLat;
      lng = newLng;
      gpsLocked = true;
      hasGps = true;

      address =
          "${newLat.toStringAsFixed(6)}, ${newLng.toStringAsFixed(6)}";

      lastUpdate = ts != null
          ? "${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')} • ${ts.month}/${ts.day}/${ts.year}"
          : "Unknown";
    });
  }

  // ==========================================================
  // OPEN FULL MAP
  // ==========================================================
  void openOSM() {
    if (!allowLocation || lat == null || lng == null) return;

    final url =
        "https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=18/$lat/$lng";

    launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication);
  }

  // ==========================================================
  // UI
  // ==========================================================
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0E1625),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF33B5FF)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0E1625),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(),
              const SizedBox(height: 22),
              _mapCard(),
              const SizedBox(height: 22),
              _infoCard(),
              const SizedBox(height: 18),
              _howItWorks(),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // SECTIONS
  // ==========================================================
  Widget _header() {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
        ),
        const SizedBox(width: 6),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Location Tracking",
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 2),
            Text(
              "Live GPS during emergencies",
              style: TextStyle(
                  color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ],
    );
  }

  Widget _mapCard() {
    return GestureDetector(
      onTap: (hasGps && allowLocation) ? openOSM : null,
      child: Container(
        height: 300,
        decoration: BoxDecoration(
          color: const Color(0xFF162233),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white10),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: allowLocation && hasGps
              ? Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(lat!, lng!),
                        initialZoom: 16,
                        interactionOptions:
                            const InteractionOptions(
                                flags: InteractiveFlag.none),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              "https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}",
                          userAgentPackageName:
                              "com.senra.app",
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(lat!, lng!),
                              width: 44,
                              height: 44,
                              child: const Icon(
                                Icons.location_on,
                                size: 44,
                                color: Color(0xFF33B5FF),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: _statusPill(
                        gpsLocked
                            ? Icons.gps_fixed
                            : Icons.gps_not_fixed,
                        gpsLocked
                            ? "GPS Locked"
                            : "Searching GPS…",
                        gpsLocked
                            ? Colors.lightGreenAccent
                            : Colors.orangeAccent,
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child:
                          _actionPill(Icons.open_in_new, "Open map"),
                    ),
                  ],
                )
              : _privacyOverlay(),
        ),
      ),
    );
  }

  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF162233),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Current Status",
            style: TextStyle(
              color: Color(0xFF33B5FF),
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          _infoBlock(
            "Coordinates",
            address,
            multiline: true,
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white10),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _infoBlock("Last update", lastUpdate),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _infoBlock(
                  "Sharing",
                  allowLocation ? "Enabled" : "Disabled",
                  highlight: allowLocation,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _howItWorks() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF162233),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "How location works",
            style: TextStyle(
              color: Color(0xFF33B5FF),
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 14),
          _Bullet("Shared only during emergencies"),
          _Bullet("Accuracy improves outdoors"),
          _Bullet("First GPS lock may take a few minutes"),
          _Bullet("Can be disabled anytime in Settings"),
          _Bullet("Privacy-first by design"),
        ],
      ),
    );
  }

  // ==========================================================
  // HELPERS
  // ==========================================================
  Widget _privacyOverlay() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline,
              color: Colors.white70, size: 36),
          SizedBox(height: 10),
          Text("Location not available",
              style: TextStyle(color: Colors.white)),
          SizedBox(height: 6),
          Text(
            "Enable location sharing in Settings",
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _infoBlock(
    String label,
    String value, {
    bool multiline = false,
    bool highlight = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: multiline ? null : 2,
          overflow:
              multiline ? null : TextOverflow.ellipsis,
          style: TextStyle(
            color: highlight
                ? const Color(0xFF33B5FF)
                : Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _statusPill(
      IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _actionPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(label,
              style:
                  const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        "• $text",
        style: const TextStyle(
            color: Colors.white70, fontSize: 13),
      ),
    );
  }
}