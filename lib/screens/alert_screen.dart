import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';

class AlertScreen extends StatefulWidget {
  final int startSeconds;
  final String? location;

  const AlertScreen({
    super.key,
    this.location,
    this.startSeconds = 3,
  });

  @override
  State<AlertScreen> createState() => _AlertScreenState();
}

class _AlertScreenState extends State<AlertScreen> {
  late int seconds;
  Timer? timer;

  // Sound
  late AudioPlayer audioPlayer;

  // state
  bool handled = false;
  bool redirected = false;

  // alert details
  String resolvedLocation = "Processing location...";
  double? lat;
  double? lng;
  String? alertId;
  String? mapURL;
  String fallType = "Fall Detected";

  List<Map<String, String>> contacts = [];

  @override
  void initState() {
    super.initState();

    seconds = widget.startSeconds;
    audioPlayer = AudioPlayer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadArguments();
      _playAlertSound(); // 🔊 PLAY SOUND
    });

    _startCountdown();
  }

  @override
  void dispose() {
    timer?.cancel();
    audioPlayer.stop(); // 🔇 STOP SOUND
    audioPlayer.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // LOAD ARGUMENTS
  // --------------------------------------------------------------------------
  void _loadArguments() {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    if (args == null) return;

    setState(() {
      fallType = args["fallType"] ?? "Fall Detected";
      resolvedLocation = args["location"] ?? widget.location ?? "Unknown";
      lat = args["lat"];
      lng = args["lng"];
      alertId = args["alertId"];

      mapURL = args["mapURL"] ??
          ((lat != null && lng != null)
              ? "https://www.google.com/maps?q=$lat,$lng"
              : null);

      contacts = (args["contacts"] as List<dynamic>? ?? [])
          .map((e) => Map<String, String>.from(e))
          .toList();
    });
  }

  // --------------------------------------------------------------------------
  // SOUND PLAYER
  // --------------------------------------------------------------------------
  Future<void> _playAlertSound() async {
    try {
      await audioPlayer.setReleaseMode(ReleaseMode.loop); // repeat
      await audioPlayer.play(
        AssetSource('sounds/alert.wav'),
      );
    } catch (e) {
      debugPrint("Sound error: $e");
    }
  }

  void _stopSound() {
    audioPlayer.stop();
  }

  // --------------------------------------------------------------------------
  // COUNTDOWN TIMER
  // --------------------------------------------------------------------------
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

  // --------------------------------------------------------------------------
  // COMPLETE ALERT
  // --------------------------------------------------------------------------
  Future<void> _finalizeAlert() async {
    if (handled) return;
    handled = true;

    _stopSound();

    await _markAlertHandled();
    _goToHelpNotified();
  }

  Future<void> _markAlertHandled() async {
    if (alertId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection("alerts")
          .doc(alertId)
          .update({
        "status": "handled",
        "handled_at": FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("⚠️ Error marking alert handled: $e");
    }
  }

  // --------------------------------------------------------------------------
  // NAVIGATE TO HELP NOTIFIED
  // --------------------------------------------------------------------------
  void _goToHelpNotified() {
    if (redirected || !mounted) return;
    redirected = true;

    Navigator.pushReplacementNamed(
      context,
      "/help-notified",
      arguments: {
        "location": resolvedLocation,
        "lat": lat,
        "lng": lng,
        "mapURL": mapURL,
        "contacts": contacts,
        "alertId": alertId,
        "fallType": fallType,
        "sentTime": TimeOfDay.now().format(context),
      },
    );
  }

  // --------------------------------------------------------------------------
  // CANCEL BUTTON
  // --------------------------------------------------------------------------
  void cancelAlert() {
    timer?.cancel();
    _stopSound();
    _finalizeAlert();
    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  // --------------------------------------------------------------------------
  // UI
  // --------------------------------------------------------------------------
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
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.redAccent.withOpacity(0.32),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.redAccent.withOpacity(0.25),
                blurRadius: 30,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // HEADER ICONS
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(LucideIcons.alertTriangle, color: Colors.red, size: 26),
                  SizedBox(width: 8),
                  Icon(LucideIcons.alertCircle, color: Colors.orange, size: 26),
                ],
              ),

              const SizedBox(height: 14),

              Text(
                fallType,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.redAccent,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                "Senra detected a sudden fall.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 25),

              // LOCATION
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_on,
                      color: Colors.pinkAccent, size: 20),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      resolvedLocation,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  )
                ],
              ),

              const SizedBox(height: 22),

              const Text(
                "Sending alert in:",
                style: TextStyle(
                  color: Colors.white60,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                "${seconds}s",
                style: const TextStyle(
                  fontSize: 46,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                "Your emergency contacts will be notified automatically.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white54,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 26),

              ElevatedButton.icon(
                onPressed: cancelAlert,
                icon: const Icon(Icons.close, size: 18),
                label: const Text(
                  "Cancel Alert",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
