import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationTrackingScreen extends StatefulWidget {
  const LocationTrackingScreen({super.key});

  @override
  State<LocationTrackingScreen> createState() => _LocationTrackingScreenState();
}

class _LocationTrackingScreenState extends State<LocationTrackingScreen> {
  String? deviceId;

  double? lat;
  double? lng;

  String address = "Waiting for GPS…";
  String lastUpdate = "—";
  String accuracy = "—";

  bool loading = true;
  bool hasGps = false;

  StreamSubscription? gpsSub;

  @override
  void initState() {
    super.initState();
    _loadDevice();
  }

  @override
  void dispose() {
    gpsSub?.cancel();
    super.dispose();
  }

  // ==========================================================
  // Load paired device
  // ==========================================================
  Future<void> _loadDevice() async {
    final prefs = await SharedPreferences.getInstance();
    deviceId = prefs.getString("pairedDevice");

    if (deviceId == null || deviceId!.isEmpty) {
      setState(() => loading = false);
      return;
    }

    _listenToDeviceDocument(deviceId!);
  }

  // ==========================================================
  // Listen to Main Device Document (Firmware v10)
  // ==========================================================
  void _listenToDeviceDocument(String deviceId) {
    final ref =
        FirebaseFirestore.instance.collection("devices").doc(deviceId);

    gpsSub = ref.snapshots().listen((snap) {
      if (!snap.exists || snap.data() == null) {
        setState(() {
          hasGps = false;
          loading = false;
          address = "No GPS available yet";
          lat = null;
          lng = null;
        });
        return;
      }

      final data = snap.data()!;
      _applyGpsData(data);
    });

    setState(() => loading = false);
  }

  // ==========================================================
  // Apply Device GPS Data from Firestore
  // ==========================================================
  void _applyGpsData(Map<String, dynamic> data) {
    final double? newLat = (data["lat"] as num?)?.toDouble();
    final double? newLng = (data["lng"] as num?)?.toDouble();

    if (newLat == null || newLng == null) {
      setState(() {
        hasGps = false;
        address = "No GPS available";
      });
      return;
    }

    final rawSync = data["lastSync"];
    DateTime? ts;

    if (rawSync is Timestamp) ts = rawSync.toDate();
    if (rawSync is String) ts = DateTime.tryParse(rawSync);

    setState(() {
      lat = newLat;
      lng = newLng;
      hasGps = true;

      address = "$newLat, $newLng";

      lastUpdate = ts != null
          ? "${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}  —  ${ts.month}/${ts.day}/${ts.year}"
          : "Unknown";

      final num? hdop = data["hdop"];
      if (hdop != null) {
        if (hdop <= 1.5) accuracy = "±3m";
        else if (hdop <= 3) accuracy = "±5m";
        else accuracy = "Low";
      } else {
        accuracy = "—";
      }
    });
  }

  // ==========================================================
  // Open OpenStreetMap
  // ==========================================================
  void openOSM() {
    if (lat == null || lng == null) return;

    final url =
        "https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=18/$lat/$lng";

    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  // ==========================================================
  // UI
  // ==========================================================
  @override
  Widget build(BuildContext context) {
    final mapPreview = (lat != null && lng != null)
        ? "https://staticmap.openstreetmap.de/staticmap.php"
            "?center=$lat,$lng"
            "&zoom=16"
            "&size=600x300"
            "&markers=$lat,$lng,red"
        : "";

    return Scaffold(
      backgroundColor: const Color(0xFF0E1625),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --------------------------------------------------
              // HEADER
              // --------------------------------------------------
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back,
                        color: Colors.white70, size: 22),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    "Location Tracking",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text("Event-Based Monitoring",
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 22),

              // =====================================================
              // MAP PREVIEW
              // =====================================================
              GestureDetector(
                onTap: openOSM,
                child: Container(
                  height: 300,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF162233),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: (!hasGps || mapPreview.isEmpty)
                        ? const Center(
                            child: Text(
                              "No Location Yet",
                              style: TextStyle(color: Colors.white54),
                            ),
                          )
                        : Image.network(mapPreview, fit: BoxFit.cover),
                  ),
                ),
              ),

              const SizedBox(height: 26),

              // =====================================================
              // DETAILS CARD
              // =====================================================
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
                        Icon(Icons.location_on_rounded,
                            color: Color(0xFF33B5FF), size: 22),
                        SizedBox(width: 10),
                        Text(
                          "Current Location",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Address
                    Row(
                      children: [
                        const Icon(Icons.place_rounded,
                            color: Colors.white70, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            address,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Update + Accuracy
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _infoBlock("Last Update", lastUpdate),
                        _infoBlock("Accuracy", accuracy),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF162233),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  "Location data appears after the device sends its first GPS update.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoBlock(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
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
