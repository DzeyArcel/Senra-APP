import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'device_pairing_screen.dart';

class CaregiverInfoScreen extends StatefulWidget {
  const CaregiverInfoScreen({super.key});

  @override
  State<CaregiverInfoScreen> createState() => _CaregiverInfoScreenState();
}

class _CaregiverInfoScreenState extends State<CaregiverInfoScreen> {
  final TextEditingController nameController = TextEditingController();

  final TextEditingController emergencyName1 = TextEditingController();
  final TextEditingController emergencyPhone1 = TextEditingController();

  bool isSaving = false;
  bool showEmergencyFields = false;

  // =============================================================
  // PHONE NORMALIZER (PH)
  // =============================================================
  String? normalizePH(String input) {
    input = input.trim();

    final r1 = RegExp(r'^\+639\d{9}$');
    final r2 = RegExp(r'^09\d{9}$');
    final r3 = RegExp(r'^9\d{9}$');
    final r4 = RegExp(r'^639\d{9}$');

    if (r1.hasMatch(input)) return input;
    if (r2.hasMatch(input)) return "+63${input.substring(1)}";
    if (r3.hasMatch(input)) return "+63$input";
    if (r4.hasMatch(input)) return "+$input";

    return null;
  }

  // =============================================================
  // SAVE PROFILE (NO LOGIN LOGIC)
  // =============================================================
  Future<void> saveCaregiverInfo() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return _error("Authentication not ready. Please restart app.");
    }

    final name = nameController.text.trim();
    if (name.isEmpty) {
      return _error("Please enter your name.");
    }

    // Step 1 — ask for emergency contact first
    if (!showEmergencyFields) {
      setState(() => showEmergencyFields = true);
      return;
    }

    final emergencyPhone = normalizePH(emergencyPhone1.text);
    if (emergencyName1.text.isEmpty || emergencyPhone == null) {
      return _error("Enter valid emergency contact details.");
    }

    setState(() => isSaving = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final uid = user.uid;

      // ---------------------------------------------------------
      // CREATE / UPDATE CAREGIVER PROFILE
      // ---------------------------------------------------------
await firestore.collection("caregivers").doc(uid).set({
  "name": name,
  "phone": user.phoneNumber ?? "",
  "locationSharing": true,
  "pushNotifications": true,
  "smsNotifications": true,

  // 🔔 ensure push never disabled
  "fcmHeal": true,

  // emergency (duplicate for quick access)
  "emergencyName": emergencyName1.text.trim(),
  "emergencyPhone": emergencyPhone,

  "updatedAt": FieldValue.serverTimestamp(),
}, SetOptions(merge: true));



      // emergency contact subcollection
      await firestore
          .collection("caregivers")
          .doc(uid)
          .collection("contacts")
          .doc("primary")
          .set({
        "name": emergencyName1.text.trim(),
        "phone": emergencyPhone,
        "added_at": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      // ---------------------------------------------------------
      // CONTINUE TO DEVICE PAIRING
      // ---------------------------------------------------------
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DevicePairingScreen()),
      );
    } catch (e) {
      debugPrint("Caregiver profile save failed: $e");
      _error("Failed to save caregiver info.");
    }

    setState(() => isSaving = false);
  }

  // =============================================================
  // ERROR HANDLER
  // =============================================================
  void _error(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  // =============================================================
  // UI (UNCHANGED STYLE)
  // =============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1625),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white70),
                  ),
                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF162233),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Caregiver Information",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700),
                        ),

                        const SizedBox(height: 20),
                        _label("Your Name"),
                        _input(nameController, "Your Name"),

                        const SizedBox(height: 24),

                        if (showEmergencyFields) _emergencySection(),

                        GestureDetector(
                          onTap: isSaving ? null : saveCaregiverInfo,
                          child: Container(
                            width: double.infinity,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF33B5FF),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Center(
                              child: Text(
                                isSaving
                                    ? "Saving..."
                                    : (showEmergencyFields
                                        ? "Finish Registration"
                                        : "Next"),
                                style: const TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (isSaving)
              Container(
                color: Colors.black45,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // =============================================================
  // UI HELPERS
  // =============================================================
  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(color: Colors.white70, fontSize: 14)),
      );

  Widget _input(TextEditingController c, String hint) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101B2C),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: c,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }

  Widget _emergencySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Emergency Contact (Required)",
          style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1B2A3A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _input(emergencyName1, "Contact Name"),
              const SizedBox(height: 10),
              _input(emergencyPhone1, "09xxxxxxxxx"),
            ],
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }
}
