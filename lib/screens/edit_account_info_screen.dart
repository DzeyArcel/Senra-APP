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
  final TextEditingController phoneController = TextEditingController();

  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadCaregiverInfo();
  }

  // --------------------------------------------------------
  // 🔥 LOAD CAREGIVER INFO FROM FIRESTORE
  // --------------------------------------------------------
  Future<void> _loadCaregiverInfo() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      setState(() => loading = false);
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection("caregivers")
        .doc(uid)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      nameController.text = data["name"] ?? "";
      phoneController.text = data["phone"] ?? "";
    }

    setState(() => loading = false);
  }

  // --------------------------------------------------------
  // 🔥 SAVE UPDATED ACCOUNT INFO
  // --------------------------------------------------------
  Future<void> _saveChanges() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance
        .collection("caregivers")
        .doc(uid)
        .update({
      "name": nameController.text.trim(),
      "phone": phoneController.text.trim(),
      "updated_at": FieldValue.serverTimestamp(),
    });

    Navigator.pop(context);
  }

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
                    // -----------------------------------------
                    // BACK BUTTON + TITLE
                    // -----------------------------------------
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white70),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          "Edit Account Info",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),
                    const Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: Text(
                        "Update your caregiver details",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // ================== MAIN CARD ==================
                    Container(
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
                            children: const [
                              Icon(Icons.person_outline,
                                  color: Color(0xFF33B5FF), size: 24),
                              SizedBox(width: 10),
                              Text(
                                "Caregiver Details",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 6),
                          const Padding(
                            padding: EdgeInsets.only(left: 2),
                            child: Text(
                              "Update your name and phone number",
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                              ),
                            ),
                          ),

                          const SizedBox(height: 22),

                          // NAME LABEL
                          const Text(
                            "Name",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),

                          // NAME FIELD
                          _inputField(controller: nameController),

                          const SizedBox(height: 20),

                          // PHONE LABEL
                          const Text(
                            "Phone Number",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),

                          // PHONE FIELD
                          _inputField(controller: phoneController),

                          const SizedBox(height: 26),

                          // ================== BUTTONS ROW ==================
                          Row(
                            children: [
                              // CANCEL BUTTON
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF223247),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        "Cancel",
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 14),

                              // SAVE CHANGES BUTTON
                              Expanded(
                                child: GestureDetector(
                                  onTap: _saveChanges,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF33B5FF),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        "Save Changes",
                                        style: TextStyle(
                                          color: Colors.black87,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
    );
  }

  // ---------------------------------------------------------
  // REUSABLE INPUT FIELD
  // ---------------------------------------------------------
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
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}
