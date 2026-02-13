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
  State<LocationTrackingScreen> createState() => _LocationTrackingScreenState();
}

class _LocationTrackingScreenState extends State<LocationTrackingScreen> {
  String? deviceId;
  String caregiverId = "";

  double? lat;
  double? lng;

  String address = "Waiting for GPS…";
  String lastUpdate = "—";

  bool loading = true;
  bool hasGps = false;
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

    if (deviceId == null || deviceId!.isEmpty || caregiverId.isEmpty) {
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

    DateTime? ts;
    final rawSync = data["lastSync"];
    if (rawSync is Timestamp) ts = rawSync.toDate();
    if (rawSync is String) ts = DateTime.tryParse(rawSync);

    if (!allowLocation || newLat == null || newLng == null) {
      setState(() {
        hasGps = false;
        lat = null;
        lng = null;
        address = "Location sharing is disabled";
        lastUpdate = "—";
      });
      return;
    }

    setState(() {
      lat = newLat;
      lng = newLng;
      hasGps = true;
      address = "$newLat, $newLng";
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
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon:
                        const Icon(Icons.arrow_back, color: Colors.white70),
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
                        "Emergency-based GPS updates",
                        style:
                            TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // MAP
              GestureDetector(
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
                                    userAgentPackageName: "com.senra.app",
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

                              // STATUS
                              Positioned(
                                top: 12,
                                left: 12,
                                child: _statusPill(
                                  icon: Icons.gps_fixed,
                                  label: "Live location",
                                  color: Colors.lightGreenAccent,
                                ),
                              ),

                              // OPEN MAP
                              Positioned(
                                bottom: 12,
                                right: 12,
                                child: _actionPill(
                                  icon: Icons.open_in_new,
                                  label: "Open full map",
                                ),
                              ),
                            ],
                          )
                        : _privacyOverlay(),
                  ),
                ),
              ),

              const SizedBox(height: 26),

              // INFO CARD
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF162233),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.place_rounded,
                            color: Color(0xFF33B5FF)),
                        SizedBox(width: 10),
                        Text(
                          "Current Location",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _infoBlock("Address / Coordinates", address),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                            child:
                                _infoBlock("Last update", lastUpdate)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _infoBlock(
                                "Sharing",
                                allowLocation
                                    ? "Enabled"
                                    : "Disabled")),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // HOW IT WORKS
              Container(
                padding: const EdgeInsets.all(20),
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
                    _Bullet(
                        "Location is shared only during emergencies"),
                    _Bullet("GPS accuracy improves outdoors"),
                    _Bullet(
                        "First GPS lock may take a few minutes"),
                    _Bullet(
                        "Location sharing can be disabled anytime"),
                    _Bullet("Senra prioritizes privacy and safety"),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // UI HELPERS
  // ==========================================================
  Widget _privacyOverlay() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline,
              color: Colors.white70, size: 36),
          SizedBox(height: 10),
          Text("Location sharing is disabled",
              style: TextStyle(color: Colors.white)),
          SizedBox(height: 6),
          Text("Enable it in Settings to view location",
              style: TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }

  Widget _infoBlock(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _statusPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _actionPill({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

// ==========================================================
// BULLET
// ==========================================================
class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        "• $text",
        style:
            const TextStyle(color: Colors.white70, fontSize: 13),
      ),
    );
  }
}
