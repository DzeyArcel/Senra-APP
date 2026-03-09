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

  final int startSeconds;

  const AlertScreen({
    super.key,
    required this.alertId,
    required this.deviceId,
    required this.fallType,
    required this.vibrate,
    required this.playSound,
    required this.showLocation,
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

  double? lat;
  double? lng;

  StreamSubscription<DocumentSnapshot>? alertListener;
  StreamSubscription<DocumentSnapshot>? deviceListener;

  @override
  void initState() {
    super.initState();
    seconds = widget.startSeconds;
    _checkAlertState();
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

  Future<void> _checkAlertState() async {

    final doc = await FirebaseFirestore.instance
        .collection("alerts")
        .doc(widget.alertId)
        .get();

    if (!doc.exists) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, "/dashboard");
      return;
    }

    final data = doc.data();

    final status = data?["status"];

    lat = (data?["lat"] as num?)?.toDouble();
    lng = (data?["lng"] as num?)?.toDouble();

    if (status != "pending") {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, "/dashboard");
      return;
    }

    setState(() {});

    _startListeners();
    _startCountdown();
    _verifyAndStartFeedback();
  }

  Future<void> _verifyAndStartFeedback() async {

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
      pattern: [0, 1000, 500, 1000],
      repeat: 0,
    );
  }

  void _stopVibration() {
    Vibration.cancel();
  }

  Future<void> _playAlertSound() async {

    await audioPlayer.setReleaseMode(ReleaseMode.loop);

    await audioPlayer.play(
      AssetSource("sounds/alert.wav"),
    );
  }

  void _stopSound() {
    audioPlayer.stop();
  }

  void _startCountdown() {

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

    if (!mounted) return;

    Navigator.pushReplacementNamed(context, "/dashboard");
  }

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

          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              Row(
                children: const [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.redAccent),
                  SizedBox(width: 8),
                  Text(
                    "Fall detected",
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              if (lat != null && lng != null)
                Column(
                  children: [

                    const Text(
                      "Device Location",
                      style: TextStyle(color: Colors.white70),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      "$lat , $lng",
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),

                  ],
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
                "Emergency handling in progress.\n"
                "SMS delivery depends on mobile signal.",
                style: TextStyle(color: Colors.white38),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(

                  onPressed: handled ? null : _finalizeAlert,

                  child: Text(
                    handled ? "Sending..." : "Send Now",
                  ),

                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}