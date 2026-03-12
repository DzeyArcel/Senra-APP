import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

import '../services/notification_initializer.dart';

class AlertScreen extends StatefulWidget {
  final String alertId;
  final String deviceId;
  final String fallType;

  final bool vibrate;
  final bool playSound;
  final bool showLocation;

  final int startSeconds;

  const AlertScreen({
    super.key,
    required this.alertId,
    required this.deviceId,
    required this.fallType,
    required this.vibrate,
    required this.playSound,
    required this.showLocation,
    this.startSeconds = 8,
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
  bool feedbackStarted = false;

  double? lat;
  double? lng;

  StreamSubscription<DocumentSnapshot>? alertListener;
  StreamSubscription<DocumentSnapshot>? deviceListener;

  @override
  void initState() {
    super.initState();

    seconds = widget.startSeconds > 8 ? 8 : widget.startSeconds;

    _startListeners();
    _startCountdown();

    Future.microtask(_verifyAndStartFeedback);
  }

  @override
  void dispose() {

    timer?.cancel();
    alertListener?.cancel();
    deviceListener?.cancel();

    _stopSound();
    _stopVibration();

    audioPlayer.dispose();

    NotificationInitializer.clearActiveAlert();

    super.dispose();
  }

  Future<void> _verifyAndStartFeedback() async {

    if (feedbackStarted) return;

    feedbackStarted = true;

    if (widget.playSound) {
      await _playAlertSound();
    }

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

  Future<void> _startVibration() async {

    final hasVibrator = await Vibration.hasVibrator();

    if (hasVibrator != true) return;

    Vibration.vibrate(
      pattern: [0, 400, 200, 400, 200, 400],
      repeat: 0,
    );
  }

  void _stopVibration() {
    Vibration.cancel();
  }

  Future<void> _playAlertSound() async {

    await audioPlayer.setReleaseMode(ReleaseMode.stop);

    audioPlayer.onPlayerComplete.first.then((_) {
      if (!handled) {
        audioPlayer.play(
          AssetSource("sounds/alert.wav"),
          volume: 1.0,
        );
      }
    });

    await audioPlayer.play(
      AssetSource("sounds/alert.wav"),
      volume: 1.0,
    );
  }

  void _stopSound() {
    audioPlayer.stop();
  }

  void _startCountdown() {

    if (timer != null) return;

    timer = Timer.periodic(
      const Duration(seconds: 1),
      (t) {
        if (seconds > 1) {
          if (mounted) {
            setState(() => seconds--);
          }
        } else {
          t.cancel();
          _finalizeAlert();
        }
      },
    );
  }

  void _startListeners() {

    alertListener = FirebaseFirestore.instance
        .collection("alerts")
        .doc(widget.alertId)
        .snapshots()
        .listen((snap) {

      final data = snap.data();

      lat = (data?["lat"] as num?)?.toDouble();
      lng = (data?["lng"] as num?)?.toDouble();

      final status = data?["status"];

      if (status == "handled" ||
          status == "cancelled_by_device" ||
          status == "sms_failed") {

        _handleExternalCancel();
      }

      if (mounted) setState(() {});
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

    NotificationInitializer.clearActiveAlert();

    Navigator.of(context).pushReplacementNamed(
      "/help-notified",
      arguments: {
        "alertId": widget.alertId,
        "fallType": widget.fallType,
        "lat": lat,
        "lng": lng,
      },
    );
  }

  void _handleExternalCancel() {

    if (handled || redirected) return;

    handled = true;
    redirected = true;

    _stopSound();
    _stopVibration();

    timer?.cancel();

    NotificationInitializer.clearActiveAlert();

    if (!mounted) return;

    Navigator.pushReplacementNamed(context, "/dashboard");
  }

  @override
  Widget build(BuildContext context) {

    final alertTime = TimeOfDay.now().format(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1E),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.35),
                      blurRadius: 40,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    const Icon(
                      Icons.warning_rounded,
                      color: Colors.redAccent,
                      size: 42,
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      "Fall Detected",
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      "Device: ${widget.deviceId}",
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.access_time, color: Colors.white54, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          "Time: $alertTime",
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_on, color: Colors.white54, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          lat != null && lng != null
                              ? "${lat!.toStringAsFixed(5)}, ${lng!.toStringAsFixed(5)}"
                              : "Acquiring location...",
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 26),

                    const Text(
                      "Automatic handling in",
                      style: TextStyle(color: Colors.white54),
                    ),

                    const SizedBox(height: 6),

                    FittedBox(
                      child: Text(
                        "$seconds",
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 54,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),

                    const Text(
                      "seconds",
                      style: TextStyle(color: Colors.white38),
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      "Emergency alert has been triggered.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white38,
                        height: 1.4,
                      ),
                    ),

                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}