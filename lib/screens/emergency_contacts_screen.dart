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
  bool loading = true;
  String emergencyPhone = "";

  StreamSubscription<User?>? authSub;

  @override
  void initState() {
    super.initState();
    _listenAuth();
  }

  @override
  void dispose() {
    authSub?.cancel();
    super.dispose();
  }

  void _listenAuth() {

    authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {

      if (!mounted) return;

      caregiverId = user?.uid ?? "";

      if (caregiverId.isNotEmpty) {
        await _loadEmergencyPhone();
      }

      setState(() {
        loading = false;
      });

    });

  }

  // Load emergency phone from device document

  Future<void> _loadEmergencyPhone() async {

    final doc = await FirebaseFirestore.instance
        .collection("devices")
        .doc("GAY")
        .get();

    if (doc.exists) {
      emergencyPhone = doc.data()?["emergencyPhone"] ?? "";
    }

  }

  // Set emergency contact

  Future<void> _setEmergencyContact(String phone) async {

    try {

      await FirebaseFirestore.instance
          .collection("devices")
          .doc("GAY")
          .set({
        "emergencyPhone": phone,
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        emergencyPhone = phone;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Emergency contact selected"),
        ),
      );

    } catch (e) {
      print("Emergency contact update failed: $e");
    }

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

  Future<void> _deleteContact(String id) async {

    await FirebaseFirestore.instance
        .collection("caregivers")
        .doc(caregiverId)
        .collection("contacts")
        .doc(id)
        .delete();

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
                                _deleteContact(doc.id),

                          ),

                        );

                      }).toList(),
                    ),

                  const SizedBox(height: 30),

                  Container(

                    padding: const EdgeInsets.all(18),

                    decoration: BoxDecoration(
                      color: const Color(0xFF162233),
                      borderRadius:
                          BorderRadius.circular(14),
                    ),

                    child: const Column(

                      crossAxisAlignment:
                          CrossAxisAlignment.start,

                      children: [

                        Text(
                          "How it works",
                          style: TextStyle(
                              color: Color(0xFF33B5FF),
                              fontWeight: FontWeight.w600,
                              fontSize: 16),
                        ),

                        SizedBox(height: 12),

                        _Bullet("- Up to 3 trusted contacts can be saved"),

                        SizedBox(height: 6),

                        _Bullet("- Tap a contact to select who receives emergency SMS alerts"),

                        SizedBox(height: 6),

                        _Bullet("- Alerts are sent automatically from the paired Senra device"),

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

class _Bullet extends StatelessWidget {

  final String text;

  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {

    return Text(
      text,
      style: const TextStyle(
          color: Colors.white70,
          fontSize: 13),
    );

  }
}