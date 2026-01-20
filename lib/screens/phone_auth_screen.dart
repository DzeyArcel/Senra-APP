// ============================================================
// PhoneAuthScreen.dart — SIMPLE AUTH (WEAK SIGNAL SAFE)
// Phase 1: Dummy OTP (123456)
// Phase 2: Replace with real Firebase Phone Auth later
// ============================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController otpController = TextEditingController();

  bool codeSent = false;
  bool isLoading = false;

  // ============================================================
  // PH PHONE NORMALIZER
  // ============================================================
  String? normalizePH(String input) {
    input = input.trim();

    final r1 = RegExp(r'^\+639\d{9}$');
    final r2 = RegExp(r'^09\d{9}$');
    final r3 = RegExp(r'^9\d{9}$');
    final r4 = RegExp(r'^639\d{9}$');

    if (r1.hasMatch(input)) return input.replaceFirst("+63", "0");
    if (r2.hasMatch(input)) return input;
    if (r3.hasMatch(input)) return "0$input";
    if (r4.hasMatch(input)) return input.replaceFirst("63", "0");

    return null;
  }

  // ============================================================
  // SEND CODE (FAKE FOR NOW)
  // ============================================================
  Future<void> sendCode() async {
    final normalized = normalizePH(phoneController.text);

    if (normalized == null) {
      return _error("Enter valid PH phone number (09xxxxxxxxx)");
    }

    setState(() {
      codeSent = true;
    });

    _info("OTP sent (use 123456)");
  }

  // ============================================================
  // VERIFY CODE (FAKE OTP)
  // ============================================================
  Future<void> verifyCode() async {
    if (otpController.text.trim() != "123456") {
      return _error("Invalid code");
    }

    setState(() => isLoading = true);

    try {
      // 🔐 TEMP AUTH — STABLE UID
      final userCred = await FirebaseAuth.instance.signInAnonymously();
      final uid = userCred.user!.uid;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("authUid", uid);
      await prefs.setBool("auth_complete", true);

      if (!mounted) return;

      Navigator.pushReplacementNamed(context, "/caregiver-info");
    } catch (e) {
      _error("Authentication failed");
    }

    setState(() => isLoading = false);
  }

  // ============================================================
  // UI HELPERS
  // ============================================================
  void _error(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  void _info(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green),
    );
  }

  // ============================================================
  // UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1625),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),

                  const Text(
                    "Verify Your Phone",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 10),
                  const Text(
                    "This helps secure alerts and device pairing.",
                    style: TextStyle(color: Colors.white70),
                  ),

                  const SizedBox(height: 30),

                  _label("Phone Number"),
                  _input(phoneController, "09xxxxxxxxx", enabled: !codeSent),

                  const SizedBox(height: 20),

                  if (codeSent) ...[
                    _label("Verification Code"),
                    _input(otpController, "123456"),
                    const SizedBox(height: 10),
                    const Text(
                      "Use code: 123456",
                      style: TextStyle(color: Colors.white38),
                    ),
                  ],

                  const SizedBox(height: 30),

                  GestureDetector(
                    onTap: isLoading
                        ? null
                        : (codeSent ? verifyCode : sendCode),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF33B5FF),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Center(
                        child: Text(
                          isLoading
                              ? "Verifying..."
                              : (codeSent ? "Verify" : "Send Code"),
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (isLoading)
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

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(color: Colors.white70, fontSize: 14)),
      );

  Widget _input(
    TextEditingController c,
    String hint, {
    bool enabled = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101B2C),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: c,
        enabled: enabled,
        keyboardType: TextInputType.phone,
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
}
