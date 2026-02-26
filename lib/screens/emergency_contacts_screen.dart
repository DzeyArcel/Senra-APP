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

  // =====================================================
  // 🔐 LISTEN TO AUTH (SOURCE OF TRUTH)
  // =====================================================
  void _listenAuth() {
    authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;

      setState(() {
        caregiverId = user?.uid ?? "";
        loading = false;
      });
    });
  }

  // =====================================================
  // 🗑 DELETE EMERGENCY CONTACT (APP + DEVICE SYNC)
  // =====================================================
  Future<void> _deleteContact() async {
    if (caregiverId.isEmpty) return;

    // 1️⃣ Delete caregiver contact
    await FirebaseFirestore.instance
        .collection("caregivers")
        .doc(caregiverId)
        .collection("contacts")
        .doc("primary")
        .delete();

    // 2️⃣ CLEAR emergencyPhone in DEVICE DOC (FIRMWARE SAFETY)
    final deviceSnap = await FirebaseFirestore.instance
        .collection("devices")
        .where("pairedTo", isEqualTo: caregiverId)
        .limit(1)
        .get();

    if (deviceSnap.docs.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection("devices")
          .doc(deviceSnap.docs.first.id)
          .set({
        "emergencyPhone": "",
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
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

    if (caregiverId.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF0E1625),
        body: Center(
          child: Text(
            "No caregiver session.\nPlease log in again.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0E1625),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection("caregivers")
              .doc(caregiverId)
              .collection("contacts")
              .doc("primary") // 🔥 SINGLE SOURCE
              .snapshots(),
          builder: (context, snap) {
            final exists = snap.data?.exists ?? false;
            final data = snap.data?.data() as Map<String, dynamic>?;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ================= HEADER =================
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white70),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        "Emergency\nContact",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                      const Spacer(),
                      if (!exists)
                        GestureDetector(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => const AddContactModal(),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF33B5FF),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.add,
                                    color: Colors.white, size: 18),
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

                  const SizedBox(height: 10),
                  const Text(
                    "One trusted contact will be notified during emergencies.",
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),

                  const SizedBox(height: 24),

                  // ================= CONTACT =================
                  if (!snap.hasData)
                    const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF33B5FF)),
                    )
                  else if (!exists)
                    const Text(
                      "No emergency contact yet.\nAdd one trusted person.",
                      style:
                          TextStyle(color: Colors.white60, fontSize: 13),
                    )
                  else
                    _contactCard(
                      name: data?["name"] ?? "Unknown",
                      phone: data?["phone"] ?? "",
                      onDelete: _deleteContact,
                    ),

                  const SizedBox(height: 30),

                  // ================= HOW IT WORKS =================
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
                        _Bullet(
                            "- This contact is notified when a fall is confirmed"),
                        SizedBox(height: 6),
                        _Bullet(
                            "- Alerts are sent from the paired Senra device"),
                        SizedBox(height: 6),
                        _Bullet(
                            "- Only one emergency contact is supported"),
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

  // =====================================================
  // CONTACT CARD
  // =====================================================
  Widget _contactCard({
    required String name,
    required String phone,
    required VoidCallback onDelete,
  }) {
    return Container(
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
              const Spacer(),
              GestureDetector(
                onTap: onDelete,
                child: const Icon(Icons.delete,
                    color: Colors.redAccent),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.phone,
                  color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(phone,
                  style: const TextStyle(color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }
}

// =====================================================
// BULLET
// =====================================================
class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: Colors.white70, fontSize: 13),
    );
  }
}