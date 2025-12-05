import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddContactModal extends StatefulWidget {
  const AddContactModal({super.key});

  @override
  State<AddContactModal> createState() => _AddContactModalState();
}

class _AddContactModalState extends State<AddContactModal> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController relationshipController =
      TextEditingController();

  String caregiverId = "";
  bool saving = false;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadCaregiverId();
  }

  Future<void> _loadCaregiverId() async {
    final prefs = await SharedPreferences.getInstance();
    caregiverId = prefs.getString("caregiverId") ?? "";
    setState(() => loading = false);
  }

  Future<void> _saveContact() async {
    if (caregiverId.isEmpty) return;

    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final email = emailController.text.trim();
    final relation = relationshipController.text.trim();

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
      await FirebaseFirestore.instance
          .collection("caregivers")
          .doc(caregiverId)
          .collection("contacts")
          .add({
        "name": name,
        "phone": phone,
        "email": email,
        "relation": relation,
        "created_at": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context); // close modal
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to save contact."),
          backgroundColor: Colors.redAccent,
        ),
      );
    }

    if (mounted) setState(() => saving = false);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF162233),
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF33B5FF)),
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF162233),
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Add Emergency Contact",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              "Add a new person to your emergency contact list",
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Name
            const Text("Full Name",
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 6),
            _inputField(controller: nameController, hint: "Enter full name"),
            const SizedBox(height: 16),

            // Phone
            const Text("Phone Number",
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 6),
            _inputField(
                controller: phoneController, hint: "(09xx xxx xxxx)"),
            const SizedBox(height: 16),

            // Email
            const Text("Email (Optional)",
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 6),
            _inputField(
                controller: emailController, hint: "email@example.com"),
            const SizedBox(height: 16),

            // Relationship
            const Text("Relationship",
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 6),
            _inputField(
                controller: relationshipController,
                hint: "e.g., Son, Daughter, Friend"),

            const SizedBox(height: 22),

            // ADD BUTTON
            GestureDetector(
              onTap: saving ? null : _saveContact,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF33B5FF),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Center(
                  child: Text(
                    saving ? "Saving..." : "Add Contact",
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // CANCEL BUTTON
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B2A3A),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Center(
                  child: Text(
                    "Cancel",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101B2C),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
