// ============================================================
// AlertScreen.dart — SENRA FINAL EMERGENCY FLOW (2026)
// - Caregiver CANNOT cancel alert
// - Only device / elder can cancel
// - Vibration strictly respects toggle
// - No infinite vibration (OEM safe)
// - Firestore verified before feedback
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

class AlertScreen extends StatefulWidget {
  final String alertId;
  final String deviceId;
  final String fallType;

  final bool vibrate;
  final bool playSound;
  final bool showLocation;

  final double? lat;
  final double? lng;
  final String locationLabel;
  final int startSeconds;

  const AlertScreen({
    super.key,
    required this.alertId,
    required this.deviceId,
    required this.fallType,
    required this.vibrate,
    required this.playSound,
    required this.showLocation,
    this.lat,
    this.lng,
    this.locationLabel = "",
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

  StreamSubscription<DocumentSnapshot>? alertListener;
  StreamSubscription<DocumentSnapshot>? deviceListener;

  // ============================================================
  // INIT
  // ============================================================
  @override
  void initState() {
    super.initState();

    seconds = widget.startSeconds;

    _startListeners();
    _startCountdown();
    _verifyAndStartFeedback(); // 🔥 SAFE ENTRY POINT
  }

  @override
  void dispose() {
    timer?.cancel();
    alertListener?.cancel();
    deviceListener?.cancel();
    _stopSound();
    _stopVibration();
    audioPlayer.dispose();
    super.dispose();
  }

  // ============================================================
  // 🔐 VERIFY SETTINGS BEFORE FEEDBACK (CRITICAL FIX)
  // ============================================================
  Future<void> _verifyAndStartFeedback() async {
    // 🔊 Sound can start immediately
    if (widget.playSound) {
      await _playAlertSound();
    }

    // 📳 Vibration must be re-verified from Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snap = await FirebaseFirestore.instance
        .collection("caregivers")
        .doc(user.uid)
        .get();

    if (!snap.exists) return;

    final bool vibrateEnabled =
        snap.data()?["emergencyVibration"] == true;

    if (vibrateEnabled) {
      _startVibration();
    }
  }

  // ============================================================
  // 📳 VIBRATION (ONE-SHOT, TOGGLE SAFE)
  // ============================================================
  Future<void> _startVibration() async {
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator != true) return;

    // ✅ ONE-TIME vibration only
    Vibration.vibrate(
      pattern: [0, 1000, 500, 1000],
    );
  }

  void _stopVibration() {
    Vibration.cancel();
  }

  // ============================================================
  // 🔊 SOUND
  // ============================================================
  Future<void> _playAlertSound() async {
    await audioPlayer.setReleaseMode(ReleaseMode.loop);
    await audioPlayer.play(AssetSource("sounds/alert.wav"));
  }

  void _stopSound() {
    audioPlayer.stop();
  }

  // ============================================================
  // ⏱ COUNTDOWN
  // ============================================================
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

  // ============================================================
  // 🔥 FIRESTORE LISTENERS
  // ============================================================
  void _startListeners() {
    alertListener = FirebaseFirestore.instance
        .collection("alerts")
        .doc(widget.alertId)
        .snapshots()
        .listen((snap) {
      final status = snap.data()?["status"];
      if (status == "handled" || status == "cancelled_by_device") {
        _handleExternalCancel();
      }
    });

    deviceListener = FirebaseFirestore.instance
        .collection("devices")
        .doc(widget.deviceId)
        .snapshots()
        .listen((snap) {
      final status = snap.data()?["fallStatus"];
      if (status == "cancelled_by_device") {
        _handleExternalCancel();
      }
    });
  }

  // ============================================================
  // 🚨 FINALIZE ALERT (AUTO OR SEND NOW)
  // ============================================================
  Future<void> _finalizeAlert() async {
    if (handled) return;
    handled = true;

    _stopSound();
    _stopVibration();
    timer?.cancel();

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

    Navigator.pushReplacementNamed(
      context,
      "/help-notified",
      arguments: {
        "alertId": widget.alertId,
        "fallType": widget.fallType,
        "lat": widget.showLocation ? widget.lat : null,
        "lng": widget.showLocation ? widget.lng : null,
      },
    );
  }

  // ============================================================
  // ❌ EXTERNAL CANCEL (DEVICE / ELDER ONLY)
  // ============================================================
  void _handleExternalCancel() {
    if (handled || redirected) return;

    handled = true;
    redirected = true;

    _stopSound();
    _stopVibration();
    timer?.cancel();

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, "/dashboard");
  }

  // ============================================================
  // UI
  // ============================================================
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
            border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.redAccent.withOpacity(0.3),
                blurRadius: 40,
                spreadRadius: 6,
              ),
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              SizedBox(width: 8),
              Text(
                "Fall detected",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ]),
            const SizedBox(height: 14),

            if (widget.showLocation && widget.locationLabel.isNotEmpty)
              Text(
                widget.locationLabel,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              )
            else
              const Text(
                "Location sharing disabled",
                style: TextStyle(color: Colors.white38),
              ),

            const SizedBox(height: 24),

            Text(
              "$seconds s",
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 44,
                fontWeight: FontWeight.w900,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              "Emergency alert will be sent automatically",
              style: TextStyle(color: Colors.white38),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _finalizeAlert,
                child: const Text("Send Now"),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
