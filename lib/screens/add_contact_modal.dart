import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddContactModal extends StatefulWidget {
  const AddContactModal({super.key});

  @override
  State<AddContactModal> createState() => _AddContactModalState();
}

class _AddContactModalState extends State<AddContactModal> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();

  bool saving = false;

  Future<void> _saveContact() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final name = nameController.text.trim();
    final phone = phoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Name and phone number are required."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => saving = true);

    await FirebaseFirestore.instance
        .collection("caregivers")
        .doc(user.uid)
        .collection("contacts")
        .add({
      "name": name,
      "phone": phone,
      "created_at": FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
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
            const Text(
              "Add Emergency Contact",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),

            _field("Full Name", nameController),
            _field("Phone Number", phoneController),

            const SizedBox(height: 20),

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
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
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

  Widget _field(String label, TextEditingController c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF101B2C),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              controller: c,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
