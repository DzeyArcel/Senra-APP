import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditAccountInfoScreen extends StatefulWidget {
  const EditAccountInfoScreen({super.key});

  @override
  State<EditAccountInfoScreen> createState() => _EditAccountInfoScreenState();
}

class _EditAccountInfoScreenState extends State<EditAccountInfoScreen> {
  final TextEditingController nameController = TextEditingController();

  bool loading = true;
  String caregiverId = "";
  String phoneNumber = "";

  @override
  void initState() {
    super.initState();
    _loadCaregiverInfo();
  }

  // ============================================================
  // LOAD CAREGIVER INFO (AUTH = SOURCE OF TRUTH)
  // ============================================================
  Future<void> _loadCaregiverInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => loading = false);
      return;
    }

    caregiverId = user.uid;

    final doc = await FirebaseFirestore.instance
        .collection("caregivers")
        .doc(caregiverId)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      nameController.text = data["name"] ?? "";
      phoneNumber = data["phone"] ?? user.phoneNumber ?? "";
    }

    setState(() => loading = false);
  }

  // ============================================================
  // SAVE NAME ONLY (🔥 CRITICAL FIX)
  // ============================================================
  Future<void> _saveChanges() async {
    final name = nameController.text.trim();

    if (name.isEmpty) {
      _showMessage("Name cannot be empty.");
      return;
    }

    await FirebaseFirestore.instance
        .collection("caregivers")
        .doc(caregiverId)
        .set({
      "name": name,
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _showMessage("Name updated");
    if (mounted) Navigator.pop(context);
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF33B5FF),
      ),
    );
  }

  // ============================================================
  // UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1625),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF33B5FF)),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HEADER
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white70),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          "Edit Account",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF162233),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Name",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 14)),
                          const SizedBox(height: 6),
                          _inputField(controller: nameController),

                          const SizedBox(height: 20),

                          const Text("Phone Number",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 14)),
                          const SizedBox(height: 6),
                          _readonlyField(phoneNumber),

                          const SizedBox(height: 26),

                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: _button(
                                      "Cancel", const Color(0xFF223247)),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: GestureDetector(
                                  onTap: _saveChanges,
                                  child: _button(
                                      "Save", const Color(0xFF33B5FF),
                                      textColor: Colors.black),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _inputField({required TextEditingController controller}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101B2C),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }

  Widget _readonlyField(String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF101B2C),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        value,
        style: const TextStyle(color: Colors.white70),
      ),
    );
  }

  Widget _button(String text, Color bg,
      {Color textColor = Colors.white}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(text,
            style:
                TextStyle(color: textColor, fontWeight: FontWeight.w700)),
      ),
    );
  }
}