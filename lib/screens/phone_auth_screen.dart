import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final phoneController = TextEditingController();
  final otpController = TextEditingController();

  bool codeSent = false;
  bool loading = false;
  String verificationId = "";

  // 🇵🇭 Normalize PH → +639XXXXXXXXX
  String? normalizePH(String input) {
    input = input.replaceAll(RegExp(r'[^0-9+]'), '');
    if (RegExp(r'^09\d{9}$').hasMatch(input)) {
      return "+63${input.substring(1)}";
    }
    if (RegExp(r'^\+639\d{9}$').hasMatch(input)) {
      return input;
    }
    return null;
  }

  // ================= SEND OTP =================
  Future<void> sendOTP() async {
    final phone = normalizePH(phoneController.text);

    if (phone == null) {
      _error("Use format: 09XXXXXXXXX");
      return;
    }

    setState(() => loading = true);

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),

      verificationCompleted: (credential) async {
        final userCred =
            await FirebaseAuth.instance.signInWithCredential(credential);
        await _afterLogin(userCred.user!);
      },

      verificationFailed: (e) {
        if (!mounted) return;
        setState(() => loading = false);
        _error(e.message ?? "OTP failed. Try again.");
      },

      codeSent: (id, _) {
        verificationId = id;
        if (!mounted) return;
        setState(() {
          codeSent = true;
          loading = false;
        });
        _info("OTP sent to your phone");
      },

      codeAutoRetrievalTimeout: (id) {
        verificationId = id;
      },
    );
  }

  // ================= VERIFY OTP =================
  Future<void> verifyOTP() async {
    if (otpController.text.length != 6) {
      _error("Enter the 6-digit code");
      return;
    }

    setState(() => loading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otpController.text.trim(),
      );

      final userCred =
          await FirebaseAuth.instance.signInWithCredential(credential);

      await _afterLogin(userCred.user!);
    } catch (_) {
      _error("Invalid OTP");
    }

    if (mounted) setState(() => loading = false);
  }

  // ================= AFTER LOGIN =================
  Future<void> _afterLogin(User user) async {
    final ref =
        FirebaseFirestore.instance.collection("caregivers").doc(user.uid);

    final fcm = await FirebaseMessaging.instance.getToken();
    final snap = await ref.get();

    if (!snap.exists) {
      await ref.set({
        "phone": user.phoneNumber,
        "devices": [],
        "fcmToken": fcm,
        "createdAt": FieldValue.serverTimestamp(),
      });
    } else {
      await ref.update({"fcmToken": fcm});
    }

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, "/startup", (_) => false);
  }

  // ================= UI HELPERS =================
  void _error(String m) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.red));
  }

  void _info(String m) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.green));
  }

  // ================= UI =================
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
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "This helps secure alerts and device pairing.",
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 24),

                  // 🔐 Robot notice (UX only)
                  if (!codeSent)
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF162233),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.security,
                              color: Color(0xFF33B5FF), size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "For security, Google may ask you to confirm "
                              "you’re not a robot. This is quick and normal.",
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),

                  _label("Phone Number"),
                  _field(phoneController, "09XXXXXXXXX",
                      enabled: !codeSent),

                  if (codeSent) ...[
                    const SizedBox(height: 20),
                    _label("Verification Code"),
                    _field(otpController, "Enter OTP"),
                  ],

                  const SizedBox(height: 30),

                  GestureDetector(
                    onTap: loading
                        ? null
                        : codeSent
                            ? verifyOTP
                            : sendOTP,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF33B5FF),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Center(
                        child: Text(
                          loading
                              ? "Please wait…"
                              : codeSent
                                  ? "Verify"
                                  : "Send OTP",
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

            if (loading)
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

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child:
            Text(t, style: const TextStyle(color: Colors.white70)),
      );

  Widget _field(TextEditingController c, String hint,
      {bool enabled = true}) {
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