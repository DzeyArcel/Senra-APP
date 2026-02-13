// ============================================================
// PhoneAuthScreen.dart — REAL AUTH (WEAK SIGNAL SAFE)
// - Keeps original UI
// - Real Firebase Phone Auth
// - FIXED: OTP → FCM → pushNotifications
// ============================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

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

  String _verificationId = "";

  // ============================================================
  // PH PHONE NORMALIZER
  // ============================================================
  String? normalizePH(String input) {
    input = input.trim();

    final r1 = RegExp(r'^\+639\d{9}$');
    final r2 = RegExp(r'^09\d{9}$');
    final r3 = RegExp(r'^9\d{9}$');
    final r4 = RegExp(r'^639\d{9}$');

    if (r1.hasMatch(input)) return input;
    if (r2.hasMatch(input)) return input.replaceFirst("0", "+63");
    if (r3.hasMatch(input)) return "+63$input";
    if (r4.hasMatch(input)) return "+$input";

    return null;
  }

  // ============================================================
  // POST-LOGIN HANDLER (🔥 FIXED)
  // ============================================================
  Future<void> _afterLogin(User user) async {
    final uid = user.uid;

    final cgRef =
        FirebaseFirestore.instance.collection("caregivers").doc(uid);

    // 🔔 Always get fresh FCM token
    final fcmToken = await FirebaseMessaging.instance.getToken();

    final snap = await cgRef.get();

    if (!snap.exists) {
      // 🆕 First-time caregiver
      await cgRef.set({
        "phone": user.phoneNumber,
        "devices": [],
        "fcmToken": fcmToken,
        "pushNotifications": true,
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      });
    } else {
      // 🔁 OTP relogin / app update / token refresh
      await cgRef.update({
        "fcmToken": fcmToken,
        "pushNotifications": true,
        "updatedAt": FieldValue.serverTimestamp(),
      });
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("auth_complete", true);

    if (!mounted) return;

    // 🔁 Always return to StartupRouter
    Navigator.pushReplacementNamed(context, "/startup");
  }

  // ============================================================
  // SEND OTP (REAL FIREBASE)
  // ============================================================
  Future<void> sendCode() async {
    final normalized = normalizePH(phoneController.text);

    if (normalized == null) {
      return _error("Enter valid PH phone number (09xxxxxxxxx)");
    }

    setState(() => isLoading = true);

    bool callbackFired = false;

    // ⏱ Safety timeout (15s)
    Future.delayed(const Duration(seconds: 15), () {
      if (!callbackFired && mounted) {
        setState(() => isLoading = false);
        _error("Verification timeout. Check network or Firebase setup.");
      }
    });

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: normalized,
      timeout: const Duration(seconds: 60),

      verificationCompleted: (credential) async {
        callbackFired = true;
        final userCred =
            await FirebaseAuth.instance.signInWithCredential(credential);
        await _afterLogin(userCred.user!);
      },

      verificationFailed: (e) {
        callbackFired = true;
        if (mounted) {
          setState(() => isLoading = false);
          _error(e.message ?? "Verification failed");
        }
      },

      codeSent: (id, _) {
        callbackFired = true;
        _verificationId = id;
        if (mounted) {
          setState(() {
            codeSent = true;
            isLoading = false;
          });
          _info("OTP sent");
        }
      },

      codeAutoRetrievalTimeout: (id) {
        _verificationId = id;
      },
    );
  }

  // ============================================================
  // VERIFY OTP (MANUAL)
  // ============================================================
  Future<void> verifyCode() async {
    final code = otpController.text.trim();

    if (code.length < 6) {
      return _error("Invalid code");
    }

    setState(() => isLoading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: code,
      );

      final userCred =
          await FirebaseAuth.instance.signInWithCredential(credential);

      await _afterLogin(userCred.user!);
    } catch (_) {
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
                    _input(otpController, "Enter OTP"),
                  ],

                  const SizedBox(height: 30),

                  GestureDetector(
                    onTap:
                        isLoading ? null : (codeSent ? verifyCode : sendCode),
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
                              ? "Processing..."
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
