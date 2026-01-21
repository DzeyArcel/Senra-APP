// ============================================================
// AlertScreen.dart — SENRA BEST-PRACTICE VERSION (2026)
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

class AlertScreen extends StatefulWidget {
  final String alertId;
  final String deviceId;
  final String fallType;

  // 🔥 DECISIONS PASSED IN (NO FETCHING HERE)
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

    _startImmediateFeedback(); // 🔥 instant
    _startListeners();
    _startCountdown();
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
  // 🔥 IMMEDIATE FEEDBACK (NO ASYNC)
  // ============================================================
  void _startImmediateFeedback() {
    if (widget.playSound) _playAlertSound();
    if (widget.vibrate) _startVibration();
  }

  // ============================================================
  // VIBRATION
  // ============================================================
  Future<void> _startVibration() async {
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(
        pattern: [0, 1000, 500, 1000, 500, 1000],
        repeat: 0,
      );
    }
  }

  void _stopVibration() => Vibration.cancel();

  // ============================================================
  // SOUND
  // ============================================================
  Future<void> _playAlertSound() async {
    await audioPlayer.setReleaseMode(ReleaseMode.loop);
    await audioPlayer.play(AssetSource("sounds/alert.wav"));
  }

  void _stopSound() => audioPlayer.stop();

  // ============================================================
  // COUNTDOWN
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
  // FIRESTORE LISTENERS
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
  // SEND ALERT
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

    Navigator.pushReplacementNamed(context, "/help-notified", arguments: {
      "alertId": widget.alertId,
      "fallType": widget.fallType,
      "lat": widget.showLocation ? widget.lat : null,
      "lng": widget.showLocation ? widget.lng : null,
    });
  }

  // ============================================================
  // CANCEL ALERT
  // ============================================================
  Future<void> _cancelAlert() async {
    if (handled) return;
    handled = true;
    redirected = true;

    _stopSound();
    _stopVibration();
    timer?.cancel();

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

  // ============================================================
  // EXTERNAL CANCEL
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
                    fontWeight: FontWeight.bold),
              ),
            ]),
            const SizedBox(height: 14),

            // 📍 LOCATION DISPLAY
            if (widget.showLocation && widget.locationLabel.isNotEmpty)
              Text(widget.locationLabel,
                  style: const TextStyle(color: Colors.white))
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
                  fontWeight: FontWeight.w900),
            ),

            const SizedBox(height: 10),
            const Text(
              "Auto-sending emergency alert",
              style: TextStyle(color: Colors.white38),
            ),

            const SizedBox(height: 28),

            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _cancelAlert,
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
