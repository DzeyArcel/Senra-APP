import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddContactModal extends StatefulWidget {
  final String? contactId;
  final String? existingName;
  final String? existingPhone;

  const AddContactModal({
    super.key,
    this.contactId,
    this.existingName,
    this.existingPhone,
  });

  @override
  State<AddContactModal> createState() => _AddContactModalState();
}

class _AddContactModalState extends State<AddContactModal> {

  final nameController = TextEditingController();
  final phoneController = TextEditingController();

  bool saving = false;

  @override
  void initState() {
    super.initState();

    if (widget.existingName != null) {
      nameController.text = widget.existingName!;
    }

    if (widget.existingPhone != null) {
      phoneController.text = widget.existingPhone!;
    }
  }

  // ------------------------------------------------------------
  // NORMALIZE PH NUMBER
  // ------------------------------------------------------------

  String normalizePHNumber(String phone) {

    phone = phone.trim();

    if (phone.startsWith("09")) {
      return "+63${phone.substring(1)}";
    }

    if (phone.startsWith("639")) {
      return "+$phone";
    }

    if (phone.startsWith("+63")) {
      return phone;
    }

    return phone;
  }

  // ------------------------------------------------------------
  // SYNC CONTACTS TO DEVICE
  // ------------------------------------------------------------

  Future<void> _syncDeviceNumbers(String caregiverId) async {

    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString("pairedDevice");

    if (deviceId == null || deviceId.isEmpty) return;

    deviceId = deviceId.replaceAll('"', "").trim();

    final contacts = await FirebaseFirestore.instance
        .collection("caregivers")
        .doc(caregiverId)
        .collection("contacts")
        .orderBy("name")
        .limit(2)
        .get();

    String ownerPhone = "";
    String emergencyPhone = "";

    if (contacts.docs.isNotEmpty) {
      ownerPhone = contacts.docs[0]["phone"];
    }

    if (contacts.docs.length > 1) {
      emergencyPhone = contacts.docs[1]["phone"];
    }

    await FirebaseFirestore.instance
        .collection("devices")
        .doc(deviceId)
        .set({
      "ownerPhone": ownerPhone,
      "emergencyPhone": emergencyPhone,
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ------------------------------------------------------------
  // SAVE CONTACT
  // ------------------------------------------------------------

  Future<void> _saveContact() async {

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final name = nameController.text.trim();
    String phone = phoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Name and phone are required."),
          backgroundColor: Colors.redAccent,
        ),
      );

      return;
    }

    phone = normalizePHNumber(phone);

    setState(() => saving = true);

    try {

      final contactsRef = FirebaseFirestore.instance
          .collection("caregivers")
          .doc(user.uid)
          .collection("contacts");

      if (widget.contactId != null) {

        await contactsRef.doc(widget.contactId).update({
          "name": name,
          "phone": phone,
          "updatedAt": FieldValue.serverTimestamp(),
        });

      } else {

        final snap = await contactsRef.get();

        if (snap.docs.length >= 3) {

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Maximum 3 contacts allowed."),
              backgroundColor: Colors.redAccent,
            ),
          );

          setState(() => saving = false);
          return;
        }

        await contactsRef.add({
          "name": name,
          "phone": phone,
          "createdAt": FieldValue.serverTimestamp(),
        });

      }

      await _syncDeviceNumbers(user.uid);

      if (!mounted) return;
      Navigator.pop(context);

    } catch (e) {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to save contact: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );

    }

    if (mounted) setState(() => saving = false);
  }

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------

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

            Text(
              widget.contactId == null
                  ? "Add Emergency Contact"
                  : "Edit Emergency Contact",

              style: const TextStyle(
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
                  color: saving ? Colors.grey : const Color(0xFF33B5FF),
                  borderRadius: BorderRadius.circular(30),
                ),

                child: Center(
                  child: Text(
                    saving ? "Saving..." : "Save Contact",
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

  Widget _field(String label, TextEditingController controller) {

    final isPhone = label.contains("Phone");

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 6),

          Container(

            decoration: BoxDecoration(
              color: const Color(0xFF101B2C),
              borderRadius: BorderRadius.circular(10),
            ),

            child: TextField(

              controller: controller,

              style: const TextStyle(color: Colors.white),

              keyboardType:
                  isPhone ? TextInputType.phone : TextInputType.text,

              inputFormatters: isPhone
                  ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))]
                  : [],

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