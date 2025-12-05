import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_pairing_screen.dart';
import 'dashboard_screen.dart';

class CaregiverInfoScreen extends StatefulWidget {
  const CaregiverInfoScreen({super.key});

  @override
  State<CaregiverInfoScreen> createState() => _CaregiverInfoScreenState();
}

class _CaregiverInfoScreenState extends State<CaregiverInfoScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  final TextEditingController emergencyName1 = TextEditingController();
  final TextEditingController emergencyPhone1 = TextEditingController();

  bool isSaving = false;
  bool showEmergencyFields = false;

  // =============================================================
  // PHONE VALIDATOR (PHILIPPINES)
  // =============================================================
  String? validatePH(String input) {
    input = input.trim();

    final plus63 = RegExp(r'^\+639\d{9}$');
    final zero9 = RegExp(r'^09\d{9}$');
    final nineStart = RegExp(r'^9\d{9}$');
    final sixThree = RegExp(r'^639\d{9}$');

    if (plus63.hasMatch(input)) return input.replaceFirst('+63', '0');
    if (zero9.hasMatch(input)) return input;
    if (nineStart.hasMatch(input)) return "0$input";
    if (sixThree.hasMatch(input)) return input.replaceFirst('63', '0');

    return null;
  }

  // =============================================================
  // SAVE & LOGIN LOGIC (UPDATED + FIXED)
  // =============================================================
  Future<void> saveCaregiverInfo() async {
    final name = nameController.text.trim();
    final normalizedPhone = validatePH(phoneController.text.trim());

    if (name.isEmpty || normalizedPhone == null) {
      _error("Enter a valid name and Filipino phone number.");
      return;
    }

    setState(() => isSaving = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final prefs = await SharedPreferences.getInstance();

      // Check if caregiver already exists (NAME + PHONE)
      final searchSnap = await firestore
          .collection("caregivers")
          .where("name", isEqualTo: name)
          .where("phone", isEqualTo: normalizedPhone)
          .limit(1)
          .get();

      // =====================================================================
      // 1️⃣ NEW CAREGIVER
      // =====================================================================
      if (searchSnap.docs.isEmpty) {
        // First press → reveal emergency fields only
        if (!showEmergencyFields) {
          setState(() {
            showEmergencyFields = true;
            isSaving = false;
          });
          return;
        }

        // Validate emergency contact
        final emergencyPhone = validatePH(emergencyPhone1.text.trim());
        if (emergencyName1.text.trim().isEmpty || emergencyPhone == null) {
          setState(() => isSaving = false);
          _error("Please enter a valid emergency contact.");
          return;
        }

        // Create new caregiver
        final newRef = await firestore.collection("caregivers").add({
          "name": name,
          "phone": normalizedPhone,
          "pairedDevice": "",
          "created_at": FieldValue.serverTimestamp(),
        });

        // Emergency contact
        await newRef.collection("contacts").doc("primary").set({
          "name": emergencyName1.text.trim(),
          "phone": emergencyPhone,
          "added_at": FieldValue.serverTimestamp(),
        });

        // Save session
        await prefs.setString("caregiverId", newRef.id);
        await prefs.setString("caregiverName", name);
        await prefs.setString("caregiverPhone", normalizedPhone);

        // ⭐ REQUIRED FOR ROUTER ⭐
        await prefs.setString("pairedDevice", "");

        // Mark onboarding complete
        await prefs.setBool("onboarding_complete", true);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DevicePairingScreen()),
        );

        setState(() => isSaving = false);
        return;
      }

      // =====================================================================
      // 2️⃣ RETURNING CAREGIVER
      // =====================================================================
      final caregiverDoc = searchSnap.docs.first;
      final caregiverId = caregiverDoc.id;
      final data = caregiverDoc.data();

      // Check for emergency contact
      final contact = await firestore
          .collection("caregivers")
          .doc(caregiverId)
          .collection("contacts")
          .doc("primary")
          .get();

      if (!contact.exists) {
        // Reveal emergency fields
        if (!showEmergencyFields) {
          setState(() {
            showEmergencyFields = true;
            isSaving = false;
          });
          return;
        }

        // Validate emergency info
        final emergencyPhone = validatePH(emergencyPhone1.text.trim());
        if (emergencyName1.text.trim().isEmpty || emergencyPhone == null) {
          setState(() => isSaving = false);
          _error("Please enter emergency contact.");
          return;
        }

        // Save emergency contact
        await firestore
            .collection("caregivers")
            .doc(caregiverId)
            .collection("contacts")
            .doc("primary")
            .set({
          "name": emergencyName1.text.trim(),
          "phone": emergencyPhone,
          "added_at": FieldValue.serverTimestamp(),
        });
      }

      // Save session
      await prefs.setString("caregiverId", caregiverId);
      await prefs.setString("caregiverName", data["name"]);
      await prefs.setString("caregiverPhone", data["phone"]);

      // ⭐ NEW: Save pairedDevice locally ⭐
      final pairedDevice = data["pairedDevice"] ?? "";
      await prefs.setString("pairedDevice", pairedDevice);

      await prefs.setBool("onboarding_complete", true);

      // If already paired → Dashboard
      if (pairedDevice != "") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DevicePairingScreen()),
        );
      }
    } catch (e) {
      _error("Something went wrong.");
      debugPrint("❌ $e");
    }

    setState(() => isSaving = false);
  }

  // =============================================================
  // UI HELPERS
  // =============================================================
  void _error(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  // =============================================================
  // UI
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
                        const SizedBox(height: 6),
                        const Text(
                          "Enter your caregiver profile below.",
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),

                        const SizedBox(height: 20),
                        _label("Your Name"),
                        _input(nameController, "Your Name"),

                        const SizedBox(height: 16),
                        _label("Your Phone (+63)"),
                        _input(phoneController, "+63"),

                        const SizedBox(height: 20),

                        if (showEmergencyFields) ...[
                          const Text(
                            "Emergency Contact",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),

                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B2A3A),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _input(emergencyName1,
                                    "Emergency Contact Name"),
                                const SizedBox(height: 10),
                                _input(emergencyPhone1,
                                    "Emergency Contact Phone (+63)"),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

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
                                isSaving ? "Saving..." : "Save & Continue",
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
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
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
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
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}
