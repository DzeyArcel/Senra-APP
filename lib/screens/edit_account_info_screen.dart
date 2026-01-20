import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditAccountInfoScreen extends StatefulWidget {
  const EditAccountInfoScreen({super.key});

  @override
  State<EditAccountInfoScreen> createState() => _EditAccountInfoScreenState();
}

class _EditAccountInfoScreenState extends State<EditAccountInfoScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  bool loading = true;
  String? caregiverId;

  @override
  void initState() {
    super.initState();
    _loadCaregiverInfo();
  }

  // ============================================================
  // LOAD CAREGIVER INFO
  // ============================================================
  Future<void> _loadCaregiverInfo() async {
    final prefs = await SharedPreferences.getInstance();
    caregiverId = prefs.getString("caregiverId");

    if (caregiverId == null) {
      setState(() => loading = false);
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection("caregivers")
        .doc(caregiverId)
        .get();

    if (doc.exists) {
      nameController.text = doc.data()?["name"] ?? "";
      phoneController.text = doc.data()?["phone"] ?? ""; // should already be 09...
    }

    setState(() => loading = false);
  }

  // ============================================================
  // NORMALIZE PH PHONE NUMBER → ALWAYS RETURNS 09XXXXXXXXX
  // ============================================================
  String? normalizePH(String input) {
    input = input.replaceAll(" ", "");

    final plus63 = RegExp(r'^\+639\d{9}$');
    final zero9 = RegExp(r'^09\d{9}$');
    final nine = RegExp(r'^9\d{9}$');
    final sixThree = RegExp(r'^639\d{9}$');

    if (zero9.hasMatch(input)) return input; // Already 09

    if (plus63.hasMatch(input)) {
      return "0${input.substring(3)}"; // +639XXXXXXXXX → 09XXXXXXXXX
    }

    if (sixThree.hasMatch(input)) {
      return "0${input.substring(2)}"; // 639XXXXXXXXX → 09XXXXXXXXX
    }

    if (nine.hasMatch(input)) {
      return "0$input"; // 9XXXXXXXXX → 09XXXXXXXXX
    }

    return null; // invalid
  }

  // ============================================================
  // SAVE CHANGES
  // ============================================================
  Future<void> _saveChanges() async {
    if (caregiverId == null) return;

    final name = nameController.text.trim();
    final phoneRaw = phoneController.text.trim();

    // Case: nothing entered
    if (name.isEmpty && phoneRaw.isEmpty) {
      _showMessage("Enter at least one field to update.");
      return;
    }

    // Validate phone only IF user typed something
    String? normalizedPhone;
    if (phoneRaw.isNotEmpty) {
      normalizedPhone = normalizePH(phoneRaw);
      if (normalizedPhone == null) {
        _showMessage("Invalid phone number. Use PH format (09XXXXXXXXX).");
        return;
      }
    }

    final updateData = <String, dynamic>{};

    if (name.isNotEmpty) updateData["name"] = name;
    if (normalizedPhone != null) updateData["phone"] = normalizedPhone;

    updateData["updated_at"] = FieldValue.serverTimestamp();

    // Save to Firestore
    await FirebaseFirestore.instance
        .collection("caregivers")
        .doc(caregiverId)
        .update(updateData);

    // Update local session
    final prefs = await SharedPreferences.getInstance();
    if (name.isNotEmpty) prefs.setString("caregiverName", name);
    if (normalizedPhone != null) prefs.setString("caregiverPhone", normalizedPhone);

    _showMessage("Account updated!");
    Navigator.pop(context);
  }

  // ============================================================
  // MESSAGE SNACKBAR
  // ============================================================
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
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF33B5FF)))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HEADER
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back, color: Colors.white70),
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

                    const SizedBox(height: 30),

                    // MAIN CARD
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
                              style: TextStyle(color: Colors.white, fontSize: 14)),
                          const SizedBox(height: 6),
                          _inputField(controller: nameController),

                          const SizedBox(height: 20),

                          const Text("Phone Number (PH format: 09XXXXXXXXX)",
                              style: TextStyle(color: Colors.white, fontSize: 14)),
                          const SizedBox(height: 6),
                          _inputField(controller: phoneController),

                          const SizedBox(height: 26),

                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF223247),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Center(
                                      child: Text("Cancel",
                                          style: TextStyle(color: Colors.white70)),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 14),

                              Expanded(
                                child: GestureDetector(
                                  onTap: _saveChanges,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF33B5FF),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        "Save Changes",
                                        style: TextStyle(
                                            color: Colors.black87,
                                            fontWeight: FontWeight.w700),
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

  // INPUT FIELD
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
