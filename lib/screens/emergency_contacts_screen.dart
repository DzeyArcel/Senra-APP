import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:senra_app/screens/add_contact_modal.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {

  String caregiverId = "";
  String deviceId = "";
  bool loading = true;
  String emergencyPhone = "";

  StreamSubscription<DocumentSnapshot>? deviceSub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      caregiverId = user.uid;
      await _loadPairedDevice();
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }

  }

  Future<void> _loadPairedDevice() async {

    final caregiverDoc = await FirebaseFirestore.instance
        .collection("caregivers")
        .doc(caregiverId)
        .get();

    final data = caregiverDoc.data();

    if (data == null) return;

    if (data["pairedDevice"] != null) {
      deviceId = data["pairedDevice"];
    }
    else if (data["devices"] is List && data["devices"].isNotEmpty) {
      deviceId = data["devices"][0];
    }

    if (deviceId.isNotEmpty) {
      _listenEmergencyPhone();
    }

  }

  void _listenEmergencyPhone() {

    deviceSub = FirebaseFirestore.instance
        .collection("devices")
        .doc(deviceId)
        .snapshots()
        .listen((doc) {

      if (!mounted) return;

      setState(() {
        emergencyPhone = doc.data()?["emergencyPhone"] ?? "";
      });

    });

  }

  Future<void> _setEmergencyContact(String phone) async {

    if (deviceId.isEmpty) return;

    await FirebaseFirestore.instance
        .collection("devices")
        .doc(deviceId)
        .set({
      "emergencyPhone": phone,
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

  }

  Future<void> _openAddContact() async {

    final snap = await FirebaseFirestore.instance
        .collection("caregivers")
        .doc(caregiverId)
        .collection("contacts")
        .get();

    if (snap.docs.length >= 3) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Maximum 3 emergency contacts allowed"),
        ),
      );

      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddContactModal(),
    );

  }

  Future<void> _editContact(String id, String name, String phone) async {

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddContactModal(
        contactId: id,
        existingName: name,
        existingPhone: phone,
      ),
    );

  }

  Future<void> _confirmDelete(String id) async {

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF162233),
        title: const Text(
          "Delete Contact",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "Are you sure you want to delete this contact?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.red),
            ),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _deleteContact(id);
    }

  }

  Future<void> _deleteContact(String id) async {

    final ref = FirebaseFirestore.instance
        .collection("caregivers")
        .doc(caregiverId)
        .collection("contacts")
        .doc(id);

    final doc = await ref.get();

    if (!doc.exists) return;

    final phone = doc.data()?["phone"] ?? "";

    await ref.delete();

    if (phone == emergencyPhone && deviceId.isNotEmpty) {

      await FirebaseFirestore.instance
          .collection("devices")
          .doc(deviceId)
          .set({
        "emergencyPhone": ""
      }, SetOptions(merge: true));

      setState(() {
        emergencyPhone = "";
      });

    }

  }

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

        child: StreamBuilder<QuerySnapshot>(

          stream: FirebaseFirestore.instance
              .collection("caregivers")
              .doc(caregiverId)
              .collection("contacts")
              .snapshots(),

          builder: (context, snap) {

            if (!snap.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF33B5FF)),
              );
            }

            final docs = snap.data!.docs;

            return SingleChildScrollView(

              padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14),

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  Row(
                    children: [

                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white70),
                      ),

                      const SizedBox(width: 6),

                      const Text(
                        "Emergency\nContacts",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),

                      const Spacer(),

                      GestureDetector(
                        onTap: _openAddContact,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF33B5FF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.add,
                                  color: Colors.white,
                                  size: 18),
                              SizedBox(width: 4),
                              Text(
                                "Add",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  if (docs.isEmpty)

                    const Text(
                      "No emergency contact yet.\nAdd a trusted person.",
                      style: TextStyle(
                          color: Colors.white60,
                          fontSize: 13),
                    )

                  else

                    Column(
                      children: docs.map((doc) {

                        final data =
                            doc.data() as Map<String, dynamic>;

                        final phone = data["phone"] ?? "";
                        final isSelected = phone == emergencyPhone;

                        return InkWell(

                          onTap: () => _setEmergencyContact(phone),

                          borderRadius: BorderRadius.circular(14),

                          child: _contactCard(

                            name: data["name"] ?? "Unknown",
                            phone: phone,
                            isEmergency: isSelected,

                            onEdit: () => _editContact(
                                doc.id,
                                data["name"],
                                data["phone"]),

                            onDelete: () =>
                                _confirmDelete(doc.id),

                          ),

                        );

                      }).toList(),
                    ),

                  const SizedBox(height: 30),

                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF162233),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        Text(
                          "How it works",
                          style: TextStyle(
                              color: Color(0xFF33B5FF),
                              fontWeight: FontWeight.w600,
                              fontSize: 16),
                        ),

                        SizedBox(height: 12),

                        Text(
                          "- Up to 3 trusted contacts can be saved",
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),

                        SizedBox(height: 6),

                        Text(
                          "- Tap a contact to select who receives emergency SMS alerts",
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),

                        SizedBox(height: 6),

                        Text(
                          "- Alerts are sent automatically from the paired Senra device",
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),

                      ],
                    ),
                  ),

                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _contactCard({
    required String name,
    required String phone,
    required bool isEmergency,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {

    return Container(

      margin: const EdgeInsets.only(bottom: 12),

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: const Color(0xFF162233),
        borderRadius: BorderRadius.circular(14),
      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Row(
            children: [

              Text(name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),

              const SizedBox(width: 8),

              if (isEmergency)
                const Icon(Icons.star,
                    color: Color(0xFF33B5FF), size: 18),

              const Spacer(),

              IconButton(
                icon: const Icon(Icons.edit,
                    color: Colors.white70),
                onPressed: onEdit,
              ),

              IconButton(
                icon: const Icon(Icons.delete,
                    color: Colors.redAccent),
                onPressed: onDelete,
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            children: [

              const Icon(Icons.phone,
                  color: Colors.white70,
                  size: 18),

              const SizedBox(width: 8),

              Text(phone,
                  style: const TextStyle(
                      color: Colors.white)),
            ],
          ),

          if (isEmergency) ...[

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF33B5FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                "SMS Alert Contact",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )

          ]

        ],
      ),
    );
  }
}