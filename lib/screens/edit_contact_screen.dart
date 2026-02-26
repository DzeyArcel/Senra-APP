import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditContactScreen extends StatefulWidget {
  const EditContactScreen({super.key});

  @override
  State<EditContactScreen> createState() => _EditContactScreenState();
}

class _EditContactScreenState extends State<EditContactScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController relationController = TextEditingController();

  String caregiverId = "";
  String contactId = "";
  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFromArgs());
  }

  // ============================================================
  // LOAD ARGUMENTS + CAREGIVER ID
  // ============================================================
  Future<void> _loadFromArgs() async {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    contactId = args?["contactId"] ?? "";
    nameController.text = args?["name"] ?? "";
    phoneController.text = args?["phone"] ?? "";
    emailController.text = args?["email"] ?? "";
    relationController.text = args?["relation"] ?? "";

    final prefs = await SharedPreferences.getInstance();
    caregiverId = prefs.getString("caregiverId") ?? "";

    setState(() => loading = false);
  }

  // ============================================================
  // STEP 2 — SYNC EMERGENCY PHONE TO DEVICE DOC
  // ============================================================
  Future<void> _syncEmergencyPhoneToDevice(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString("pairedDevice");

    if (deviceId == null || deviceId.isEmpty) return;

    await FirebaseFirestore.instance
        .collection("devices")
        .doc(deviceId)
        .set({
      "emergencyPhone": phone,
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ============================================================
  // SAVE CONTACT CHANGES
  // ============================================================
  Future<void> _saveChanges() async {
    if (caregiverId.isEmpty || contactId.isEmpty) return;

    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final email = emailController.text.trim();
    final relation = relationController.text.trim();

    if (name.isEmpty || phone.isEmpty || relation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Name, phone, and relationship are required."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => saving = true);

    try {
      // 1️⃣ SAVE TO CAREGIVER CONTACTS (APP SOURCE OF TRUTH)
      await FirebaseFirestore.instance
          .collection("caregivers")
          .doc(caregiverId)
          .collection("contacts")
          .doc(contactId)
          .update({
        "name": name,
        "phone": phone,
        "email": email,
        "relation": relation,
        "updated_at": FieldValue.serverTimestamp(),
      });

      // 2️⃣ MIRROR PHONE TO DEVICE DOC (FOR FIRMWARE)
      await _syncEmergencyPhoneToDevice(phone);

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to save changes."),
          backgroundColor: Colors.redAccent,
        ),
      );
    }

    if (mounted) setState(() => saving = false);
  }

  // ============================================================
  // DELETE CONTACT
  // ============================================================
  Future<void> _deleteContact() async {
    if (caregiverId.isEmpty || contactId.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF162233),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Center(
          child: Text(
            "Delete Contact?",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
        ),
        content: const Text(
          "This emergency contact will be permanently removed.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          GestureDetector(
            onTap: () => Navigator.pop(context, true),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  "Delete Contact",
                  style:
                      TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => Navigator.pop(context, false),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF223247),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  "Cancel",
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await FirebaseFirestore.instance
        .collection("caregivers")
        .doc(caregiverId)
        .collection("contacts")
        .doc(contactId)
        .delete();

    if (!mounted) return;
    Navigator.pop(context);
  }

  // ============================================================
  // UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0E1625),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF33B5FF)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0E1625),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back,
                        color: Colors.white70, size: 22),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    "Edit Contact",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                "Update emergency contact information",
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF162233),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label("Full Name *"),
                    _inputField(controller: nameController),
                    const SizedBox(height: 16),

                    _label("Phone Number *"),
                    _inputField(controller: phoneController),
                    const SizedBox(height: 16),

                    _label("Email Address"),
                    _inputField(controller: emailController),
                    const SizedBox(height: 16),

                    _label("Relationship *"),
                    _inputField(controller: relationController),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: saving ? null : _saveChanges,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF33B5FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            saving ? "Saving..." : "Save Changes",
                            style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: _deleteContact,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.redAccent),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text(
                            "Delete Contact",
                            style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // UI HELPERS
  // ============================================================
  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white70, fontSize: 13),
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
              EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}