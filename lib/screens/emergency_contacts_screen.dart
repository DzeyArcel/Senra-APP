import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  @override
  void initState() {
    super.initState();
    _loadCaregiverId();
  }

  // ----------------------------------------------------
  // LOAD caregiverId from SharedPreferences
  // ----------------------------------------------------
  Future<void> _loadCaregiverId() async {
    final prefs = await SharedPreferences.getInstance();
    caregiverId = prefs.getString("caregiverId") ?? "";

    setState(() {
      loading = false;
    });
  }

  // ----------------------------------------------------
  // DELETE SINGLE CONTACT
  // ----------------------------------------------------
  Future<void> _deleteContact(String contactId) async {
    if (caregiverId.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF162233),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          "Delete Contact?",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        content: const Text(
          "This contact will be removed from your emergency list.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          GestureDetector(
            onTap: () => Navigator.pop(context, true),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  "Delete",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => Navigator.pop(context, false),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
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
        body: SafeArea(
          child: Center(
            child: Text(
              "No caregiver session.\nPlease restart the app.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ),
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
              // ---------------- TOP BAR ----------------
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back,
                        color: Colors.white70, size: 22),
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

                  // ADD CONTACT BUTTON
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
                          Icon(Icons.add, color: Colors.white, size: 18),
                          SizedBox(width: 4),
                          Text(
                            "Add Contact",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),
              const Text(
                "Manage your emergency contact list",
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),

              const SizedBox(height: 20),

              // ---------------- CONTACTS LIST (STREAM) ----------------
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("caregivers")
                    .doc(caregiverId)
                    .collection("contacts")
                    .orderBy("name")
                    .snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: CircularProgressIndicator(
                          color: Color(0xFF33B5FF),
                        ),
                      ),
                    );
                  }

                  final docs = snap.data!.docs;

                  if (docs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 30),
                      child: Text(
                        "No emergency contacts yet.\nAdd at least one person to be notified.",
                        style:
                            TextStyle(color: Colors.white60, fontSize: 13),
                      ),
                    );
                  }

                  return Column(
                    children: docs.map((d) {
                      final data =
                          d.data() as Map<String, dynamic>? ?? {};
                      final name = data["name"] ?? "Unknown";
                      final relation = data["relation"] ?? "Contact";
                      final phone = data["phone"] ?? "";
                      final email = data["email"] ?? "";

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _contactCard(
                          name: name,
                          relation: relation,
                          phone: phone,
                          email: email,
                          onEdit: () {
                            Navigator.pushNamed(
                              context,
                              "/edit-contact",
                              arguments: {
                                "contactId": d.id,
                                "name": name,
                                "phone": phone,
                                "email": email,
                                "relation": relation,
                              },
                            );
                          },
                          onDelete: () => _deleteContact(d.id),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

              const SizedBox(height: 20),

              // ---------------- HOW IT WORKS ----------------
              Container(
                width: double.infinity,
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
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 12),
                    _Bullet(
                        "- Emergency contacts are notified when a fall is detected"),
                    SizedBox(height: 6),
                    _Bullet(
                        "- Location information is automatically shared during alerts"),
                    SizedBox(height: 6),
                    _Bullet(
                        "- Keep at least one trusted contact for safety"),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // CONTACT CARD UI
  Widget _contactCard({
    required String name,
    required String relation,
    required String phone,
    required String email,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return Container(
      width: double.infinity,
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
              Text(
                name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  relation,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onEdit,
                child: const Icon(Icons.edit,
                    color: Color(0xFF33B5FF), size: 20),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onDelete,
                child: const Icon(Icons.delete,
                    color: Colors.redAccent, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            "Emergency Contact",
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.phone, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(phone, style: const TextStyle(color: Colors.white)),
            ],
          ),
          if (email.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.mail, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Text(email, style: const TextStyle(color: Colors.white)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// BULLET POINT TEXT
class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style:
          const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
    );
  }
}
