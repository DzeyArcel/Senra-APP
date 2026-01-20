// ============================================================
// AlertScreen.dart — FINAL SENRA VERSION (2026)
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AlertScreen extends StatefulWidget {
  final String alertId;
  final String deviceId;
  final String location;
  final double lat;
  final double lng;
  final String mapURL;
  final String fallType;
  final List<Map<String, String>> contacts;
  final int startSeconds;

  const AlertScreen({
    super.key,
    required this.alertId,
    required this.deviceId,
    required this.location,
    required this.lat,
    required this.lng,
    required this.mapURL,
    required this.fallType,
    required this.contacts,
    this.startSeconds = 30,
  });

  @override
  State<AlertScreen> createState() => _AlertScreenState();
}

class _AlertScreenState extends State<AlertScreen> {
  late int seconds;
  Timer? timer;

  final AudioPlayer audioPlayer = AudioPlayer();

  bool handled = false;
  bool redirected = false;
  bool vibrationEnabled = true;

  StreamSubscription<DocumentSnapshot>? alertListener;
  StreamSubscription<DocumentSnapshot>? deviceListener;

  @override
  void initState() {
    super.initState();

    seconds = widget.startSeconds;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadVibrationPreference();
      _initializeAlert();
      _startCountdown();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    alertListener?.cancel();
    deviceListener?.cancel();
    audioPlayer.stop();
    audioPlayer.dispose();
    _stopVibration();
    super.dispose();
  }

  // -----------------------------------------------------------
  // INITIALIZATION
  // -----------------------------------------------------------
  void _initializeAlert() {
    _startAlertStatusListener(widget.alertId);
    _startDeviceCancelListener(widget.deviceId);
    _playAlertSound();
  }

  // -----------------------------------------------------------
  // VIBRATION CONTROL
  // -----------------------------------------------------------
  Future<void> _loadVibrationPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final caregiverId = prefs.getString("caregiverId") ?? "";

    if (caregiverId.isEmpty) return;

    final doc = await FirebaseFirestore.instance
        .collection("caregivers")
        .doc(caregiverId)
        .get();

    vibrationEnabled = doc.data()?['emergencyVibration'] ?? true;

    if (vibrationEnabled) _startVibration();
  }

  Future<void> _startVibration() async {
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(pattern: [0, 1000, 500, 1000], repeat: 0);
    }
  }

  void _stopVibration() => Vibration.cancel();

  // -----------------------------------------------------------
  // AUDIO
  // -----------------------------------------------------------
  Future<void> _playAlertSound() async {
    await audioPlayer.setReleaseMode(ReleaseMode.loop);
    await audioPlayer.play(AssetSource("sounds/alert.wav"));
  }

  void _stopSound() => audioPlayer.stop();

  // -----------------------------------------------------------
  // COUNTDOWN
  // -----------------------------------------------------------
  void _startCountdown() {
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (seconds > 1) {
        if (mounted) setState(() => seconds--);
      } else {
        t.cancel();
        _finalizeAlert();
      }
    });
  }

  // -----------------------------------------------------------
  // SEND ALERT
  // -----------------------------------------------------------
  Future<void> _finalizeAlert() async {
    if (handled) return;

    handled = true;

    _stopSound();
    _stopVibration();

    try {
      await FirebaseFirestore.instance
          .collection("alerts")
          .doc(widget.alertId)
          .update({
        "status": "handled",
        "handled_at": FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    if (!mounted) return;

    Navigator.pushReplacementNamed(context, "/help-notified", arguments: {
      "location": widget.location,
      "lat": widget.lat,
      "lng": widget.lng,
      "mapURL": widget.mapURL,
      "contacts": widget.contacts,
      "alertId": widget.alertId,
      "fallType": widget.fallType,
      "sentTime": TimeOfDay.now().format(context),
    });
  }

  // -----------------------------------------------------------
  // REAL CANCEL (FALSE ALARM)
  // -----------------------------------------------------------
  Future<void> cancelAlert() async {
    if (handled) return;

    handled = true;
    redirected = true;

    timer?.cancel();
    _stopSound();
    _stopVibration();

    try {
      await FirebaseFirestore.instance
          .collection("alerts")
          .doc(widget.alertId)
          .update({
        "status": "cancelled_by_caregiver",
        "cancelled_at": FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, "/dashboard");
  }

  // -----------------------------------------------------------
  // DEVICE + CLOUD LISTENERS
  // -----------------------------------------------------------
  void _startDeviceCancelListener(String id) {
    deviceListener = FirebaseFirestore.instance
        .collection("devices")
        .doc(id)
        .snapshots()
        .listen((snap) {
      final status = snap.data()?["fallStatus"];
      if (status == "cancelled_by_device") _handleExternalCancel();
    });
  }

  void _startAlertStatusListener(String id) {
    alertListener = FirebaseFirestore.instance
        .collection("alerts")
        .doc(id)
        .snapshots()
        .listen((snap) {
      final status = snap.data()?["status"];
      if (status == "handled") _handleExternalCancel();
    });
  }

  void _handleExternalCancel() {
    if (handled || redirected) return;

    handled = true;
    redirected = true;

    timer?.cancel();
    _stopSound();
    _stopVibration();

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, "/dashboard");
  }

  // -----------------------------------------------------------
  // UI
  // -----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1E),
      body: Center(
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.redAccent.withOpacity(0.35)),
            boxShadow: [
              BoxShadow(
                color: Colors.redAccent.withOpacity(0.25),
                blurRadius: 40,
                spreadRadius: 6,
              ),
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              SizedBox(width: 8),
              Text("Fall detected",
                  style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 14),
            Text(widget.location, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 24),
            Text("$seconds s",
                style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 44,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            const Text("Auto-sending emergency alert",
                style: TextStyle(color: Colors.white38)),
            const SizedBox(height: 28),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: cancelAlert,
                  child: const Text("Cancel"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _finalizeAlert,
                  child: const Text("Send Now"),
                ),
              ),
            ])
          ]),
        ),
      ),
    );
  }
}
