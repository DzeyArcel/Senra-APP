// AllSetScreen.dart — FINAL FIXED VERSION (2025 Compatible with Firmware V14.x)
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AllSetScreen extends StatefulWidget {
  const AllSetScreen({super.key});

  @override
  State<AllSetScreen> createState() => _AllSetScreenState();
}

class _AllSetScreenState extends State<AllSetScreen> {
  bool loading = false;

  Future<void> _finishSetup() async {
    setState(() => loading = true);

    final prefs = await SharedPreferences.getInstance();
    final caregiverId = prefs.getString("caregiverId") ?? "";
    final deviceId = prefs.getString("pairedDevice") ?? "";

    // ============================================================
    // MARK ONBOARDING COMPLETE + WIFI SETUP COMPLETE
    // ============================================================
    await prefs.setBool("onboarding_complete", true);
    await prefs.setBool("needsWifiSetup", false);   // 🔥 REQUIRED FIX

    // ============================================================
    // VALIDATE CAREGIVER
    // ============================================================
    if (caregiverId.isEmpty) {
      return _go("/caregiver-info");
    }

    final cgSnap = await FirebaseFirestore.instance
        .collection("caregivers")
        .doc(caregiverId)
        .get();

    if (!cgSnap.exists) {
      await prefs.clear();
      return _go("/caregiver-info");
    }

    // ============================================================
    // VALIDATE DEVICE
    // ============================================================
    if (deviceId.isEmpty) return _go("/device-pairing");

    final devRef =
        FirebaseFirestore.instance.collection("devices").doc(deviceId);
    final devSnap = await devRef.get();

    if (!devSnap.exists) return _go("/device-connected");

    final data = devSnap.data()!;
    final rawLastSync = data["lastSync"];

    DateTime? lastSync;
    if (rawLastSync is Timestamp) lastSync = rawLastSync.toDate();
    if (rawLastSync is String) lastSync = DateTime.tryParse(rawLastSync);

    bool isOnline = false;
    if (lastSync != null) {
      final diff = DateTime.now().difference(lastSync).inSeconds;
      isOnline = diff <= 20;
    }

    // ============================================================
    // SAFETY: CLEAR adminCommand
    // ============================================================
    await devRef.update({"adminCommand": ""});

    // ============================================================
    // DEVICE ONLINE → GO TO DASHBOARD
    // ============================================================
    if (isOnline) return _go("/dashboard");

    // ============================================================
    // DEVICE STILL CONNECTING → WAIT 2 SECONDS
    // ============================================================
    await Future.delayed(const Duration(seconds: 2));

    final retrySnap = await devRef.get();
    final retryRaw = retrySnap.data()?["lastSync"];

    DateTime? retryTime;
    if (retryRaw is Timestamp) retryTime = retryRaw.toDate();
    if (retryRaw is String) retryTime = DateTime.tryParse(retryRaw);

    if (retryTime != null &&
        DateTime.now().difference(retryTime).inSeconds <= 20) {
      return _go("/dashboard");
    }

    return _go("/device-connected");
  }

  // ============================================================
  // NAVIGATION HELPER
  // ============================================================
  void _go(String route) {
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
  }

  // ============================================================
  // UI
  // ============================================================
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
              // Checkmark
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
                "Senra is now connected and keeping\nwatch over your loved one.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 50),

              GestureDetector(
                onTap: loading ? null : _finishSetup,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: loading ? Colors.grey : const Color(0xFF33B5FF),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Center(
                    child: loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
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
