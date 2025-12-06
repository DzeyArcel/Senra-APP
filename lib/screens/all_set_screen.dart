import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AllSetScreen extends StatelessWidget {
  const AllSetScreen({super.key});

  Future<void> _finishSetup(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();

    // Mark onboarding complete
    await prefs.setBool("onboarding_complete", true);

    // Validate paired device
    final deviceId = prefs.getString("pairedDevice") ?? "";
    if (deviceId.isEmpty) {
      // fallback: return to DevicePairing
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          "/device-pairing",
          (route) => false,
        );
      }
      return;
    }

    // Check device online state (lastSync rule)
    final snap = await FirebaseFirestore.instance
        .collection("devices")
        .doc(deviceId)
        .get();

    if (!snap.exists) {
      // Device deleted or not yet registered → go to device-connected
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          "/device-connected",
          (route) => false,
        );
      }
      return;
    }

    final raw = snap.data()!;
    bool online = false;

    final rawLastSync = raw["lastSync"];
    DateTime? lastSync;

    if (rawLastSync is Timestamp) lastSync = rawLastSync.toDate();
    if (rawLastSync is String) lastSync = DateTime.tryParse(rawLastSync);

    if (lastSync != null) {
      final diff = DateTime.now().difference(lastSync).inSeconds;
      online = diff <= 20;
    }

    // 🔥 FINAL ROUTING LOGIC
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        online ? "/dashboard" : "/device-connected",
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1625),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // CHECKMARK
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF162233),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF33B5FF).withOpacity(0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 50,
                ),
              ),

              const SizedBox(height: 40),

              const Text(
                "You're All Set ✨",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                "Senra is now connected and keeping\nwatch.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 50),

              GestureDetector(
                onTap: () => _finishSetup(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: const Color(0xFF33B5FF),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Center(
                    child: Text(
                      "Go to Dashboard",
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
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
